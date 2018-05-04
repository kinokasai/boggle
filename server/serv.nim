import asyncnet, asyncdispatch, sequtils, strutils, tables, options, dice, os
import patree_bin


# Fun fact: The verification phase doesn't exist in immediate mode
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
var scores: OrderedTable[int, int]
var duplicates: seq[string]
var grid: seq[char]
var state: ServerState
var turns_per_session = 3
var turn_length = 15
var score_table = {3:1, 4:1, 5:2, 6:3, 7:5}.toTable()
var dict = open("word_list_fr.txt")
var dictree : Patree


proc calculate_scores() = 
    for word, client in words.pairs():
        let score =
            if word.len < 3: 0
            elif word.len >= 8: 11
            else: score_table[word.len]
        scores[client] += score

proc transition(state: ServerState) : ServerState =
    case (state):
        of Idle:
            result = Research
        of Research:
            result = Result
            calculate_scores()
        of Verification:
            result = Result
        of Result:
            result = Idle

proc name(id: int) : string =
    result = names[id]

proc sock(id: int) : AsyncSocket =
    result = sockets[id]

proc score(id: int) : int =
    result = scores[id]

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

proc contains[A, B](t: Table[A, B], value: B) : bool =
    for data in t.values():
        if data == value:
            return true
    return false

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
    if scores.hasKey(client):
        scores.del(client)
    names.del(client)

proc signal_all(msg: string) {.async.} =
    for id in names.keys():
        await id.sock.send(msg)

proc authentify(client: int, name:string) {.async.} =
    names[client] = name
    scores[client] = 0
    echo "Player " & name & " connected."
    await client.sock.send("You're connected as " & name & "\n")
    await signal_others(client, "CONNECTE/" & name & "\n")

proc send_scores() {.async.} =
    for id in names.keys():
        let score = id.score
        await id.sock.send("BILANMOTS//" & $score & "\n")

proc start_session() {.async.} =
    if state == Idle:
        state = Research
        # Reset score on session start
        for client in names.keys():
            scores[client] = 0
        await signal_all("SESSION/" & "\n")
        for i in 0..<turns_per_session:
            state = Research
            grid = get_grid()
            await signal_all("TOUR/" & grid.join & "/" & $turn_length & "\n")
            await sleepAsync(turn_length * 1000)
            await signal_all("RFIN/\n")
            state = state.transition()
            await send_scores()
        var bilan = ""
        scores.sort(proc(a, b: (int, int)) : int = (a[1] > b[1]).int)
        for client, score in scores.pairs():
            bilan &= client.name & "*" & $score & "|"
        await signal_all("VAINQUEUR/" & bilan & "\n")
        state = Idle

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
            # We must launch session in parallel
            asyncCheck start_session()

proc process_research(client: int, cmd: seq[string]) {.async, inline.} =
    case cmd[0]:
        of "TROUVE":
            let word = cmd[1]
            if not verify_trajectory(grid, word, cmd[2]):
                await client.sock.send("MINVALIDE/POS" & "\n")
            elif dictree.lookup(word).is_none:
                await client.sock.send("MINVALIDE/DIC" & "\n")
            elif words.hasKey(word):
                duplicates.add(word)
                await client.sock.send("MINVALIDE/PRI" & "\n")
            else:
                client.add_word(word)
                await client.sock.send("MVALIDE/" & word & "\n")

proc process_state(client: int, cmd: seq[string]) {.async, inline.} =
    case state:
        of Idle:
            await process_idle(client, cmd)
        of Research:
            await process_research(client, cmd)
        of Verification:
            discard
        of Result:
            discard

proc process_always(client: int, cmd: seq[string]) {.async, inline.} =
    case cmd[0]:
        of "CONNEXION":
            if names.contains(cmd[1]):
                await client.sock.send("ENVOI/Username already taken.\n")
            elif names.hasKey(client):
                await signal_others(client, "CONNECTE/" & cmd[1] & "/" & names[client] & "\n")
                names[client] = cmd[1]
            else:
                await client.authentify(cmd[1])
        of "quit":
            await drop_client(client)
        of "":
            await drop_client(client)
            

proc process_client(client: int) {.async.} =
    let line = await client.sock.recv_line()
    echo line
    let cmd = line.split("/")
    await process_always(client, cmd)
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
    scores = initOrderedTable[int, int]()
    duplicates = @[]
    state = Idle
    grid = get_grid()
    var tline : TaintedString
    echo "Loading dictionnary..."
    while (dict.read_line(tline)):
        dictree.insert(tline)
    echo "done."

    var server = new_async_socket()
    server.set_sock_opt(OptReuseAddr, true)
    server.bind_addr(Port(3434))
    server.listen()

    while true:
        let sock = await server.accept()
        asyncCheck handle(make_client(sock))
        # asyncCheck session_manager()

grid = get_grid()

async_check register()
run_forever()