import asyncnet, asyncdispatch, sequtils, strutils, tables, options, dice

type ServerState = enum
    Idle, Research, Verification, Result

var sockets : Table[int, AsyncSocket]
# Will need to make the table robust for multithreaded code
# Basically, will need some sort of message passing between
# the main thread and client handlers.
# Or basically implement the readwrite lock.
var names : Table[int, string]
# We'll accept already proposed words, but won't count them on score
var words: Table[string, int]
var duplicates: seq[string]
var grid: seq[char]
var state: ServerState

proc transition(state: ServerState) : ServerState =
    case (state):
        of Idle:
            result = Research
        of Research:
            result = Idle
        of Verification:
            result = Result
        of Result:
            result = Idle

proc name(id: int) : string =
    result = names[id]

proc sock(id: int) : AsyncSocket =
    result = sockets[id]

proc make_client(sock: AsyncSocket) : int = 
    var id {.global.} = -1
    inc(id)
    sockets[id] = sock
    id

proc table_find[A, B](t: var Table[A, B], value: B) : Option[A] =
    for key, data in t.pairs():
        if data == value:
            return some key
    return none(A)

proc authentify(client: int, name:string) : bool =
    if names.hasKey(client):
        return false
    names[client] = name
    return true

proc add_word(client: int, word:string) =
    words[word] = client

# FIXME: Can only the connected client remove itself?
proc delete(client: int, name: string) : bool = 
    if names.hasKey(client) and names[client] != name:
        return false
    names.del(client)
    # We allow name rebinding without reconnection
    # sockets[client].close()
    # sockets.del(client)
    return true

proc signal_others(client:int, msg:string) {.async.} =
    for id in names.keys():
        if id != client:
            await id.sock.send(msg)

proc drop_client(client: int) {.async.} =
    echo("Dropping client " & $client)
    sockets[client].close()
    sockets.del(client)
    if names.hasKey(client):
        await signal_others(client, "DECONNEXION/" & $names[client] & "\n")
    names.del(client)

proc signal_all(msg: string) {.async.} =
    for id in names.keys():
        await id.sock.send(msg)

proc session_timer() {.async.} =
    await sleepAsync(10000)
    await signal_all("RFIN/" & "\n")
    state = state.transition()

proc start_session() {.async.} =
    if state == Idle:
        state = state.transition()
    asyncCheck session_timer()
    await signal_all("SESSION/" & "\n")
    grid = get_grid()
    await signal_all("TOUR/" & grid.join & "\n")

# The tricky thing is that we have concurrent state machines.
# One for every player, and one for the server as a whole.

proc process_chat(client: int, cmd: seq[string]) {.async, inline.} =
    case cmd[0]:
        of "ENVOI":
            await signal_all("RECEPTION/" & client.name & ": " & cmd[1] & "\n")
        of "PENVOI":
            let id_opt = table_find(names, cmd[1])
            if id_opt.isNone:
               await client.sock.send("No user named " & cmd[1] & "\n")
            else:
                await id_opt.get().sock.send("PRECEPTION/" & client.name &  ": " & cmd[2] & "\n")
        of "GETPLAYERS":
            var players = ""
            for name in names.values():
                players &= name & "|"
            await client.sock.send("PLAYERS/" & players & "\n")

proc process_idle(client: int, cmd: seq[string]) {.async, inline.} =
    case cmd[0]:
        of "START":
            await start_session()

proc process_research(client: int, cmd: seq[string]) {.async, inline.} =
    case cmd[0]:
        of "TROUVE":
            let word = cmd[1]
            let correct = verify_trajectory(grid, word, cmd[2])
            if correct:
                if words.hasKey(word):
                    duplicates.add(word)
                    await client.sock.send("MINVALIDE/PRI" & "\n")
                else:
                    client.add_word(word)
                    await client.sock.send("MVALIDE/" & word & "\n")
            else:
                await client.sock.send("MINVALIDE/POS" & "\n")

proc process_state(client: int, cmd: seq[string]) {.async, inline} =
    case state:
        of Idle:
            await process_idle(client, cmd)
        of Research:
            await process_research(client, cmd)
        of Verification:
            discard
        of Result:
            discard

proc process_client(client: int) {.async.} =
    let line = await client.sock.recv_line()
    echo line
    let cmd = line.split({'/'})
    # Players can connect at any time
    if cmd[0] == "CONNEXION":
        if client.authentify(cmd[1]):
            echo "Player " & cmd[1] & " connected."
            await client.sock.send("You're connected as " & cmd[1] & "\n")
            await signal_others(client, "CONNECTE/" & cmd[1] & "\n")
        else:
            await client.sock.send("Username already taken.\n")
    elif cmd[0] == "" and cmd.len == 1:
        await drop_client(client)
    if (names.hasKey(client)):
        if cmd[0] == "SORT":
            echo (cmd[1] & " quit.")
            if delete(client, cmd[1]):
                await signal_others(client, "User " & cmd[1] & " disconnected.\n")
            else:
                await client.sock.send("But you can't deconnect someone else!\n")
        await process_chat(client, cmd)
        await process_state(client, cmd)

proc handle(client: int) {.async.} =
    while true:
        # If there's no more socket, drop the client
        if not sockets.hasKey(client):
            break
        await process_client(client)

proc register() {.async.} =
    sockets = initTable[int, AsyncSocket]()
    names = initTable[int, string]()
    words = initTable[string, int]()
    duplicates = @[]
    state = Idle
    grid = get_grid()

    var server = new_async_socket()
    server.set_sock_opt(OptReuseAddr, true)
    server.bind_addr(Port(3434))
    server.listen()
    while true:
        let sock = await server.accept()
        asyncCheck handle(make_client(sock))

grid = get_grid()

async_check register()
run_forever()