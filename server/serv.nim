import asyncnet, asyncdispatch, sequtils, strutils, tables, options


var sockets : Table[int, AsyncSocket]
# Will need to make the table robust for multithreaded code
# Basically, will need some sort of message passing between
# the main thread and client handlers.
# Or basically implement the readwrite lock.
var names : Table[int, string]

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

proc process_client(client: int) {.async.} =
    let line = await client.sock.recv_line()
    let cmd = line.split({'/'})
    case cmd[0]:
        of "CONNEXION":
            if client.authentify(cmd[1]):
                echo "Player " & cmd[1] & " connected."
                await client.sock.send("You're connected as " & cmd[1] & "\n")
                await signal_others(client, "CONNECTE/" & cmd[1] & "\n")
            else:
                await client.sock.send("Username already taken.\n")
        of "SORT":
            echo (cmd[1] & " quit.")
            if delete(client, cmd[1]):
                await signal_others(client, "User " & cmd[1] & " disconnected.\n")
            else:
                await client.sock.send("But you can't deconnect someone else!\n")
        of "ENVOI":
            # Can't chat if you're not authenticated.
            if names.hasKey(client):
                await signal_all("RECEPTION/" & client.name & ": " & cmd[1] & "\n")
            else:
                await client.sock.send("Need to connect before sending messages.\n")
        of "PENVOI":
            if names.hasKey(client):
                let id_opt = table_find(names, cmd[1])
                if id_opt.isNone:
                    await client.sock.send("No user named " & cmd[1] & "\n")
                else:
                    await id_opt.get().sock.send(client.name &  ": " & cmd[2] & "\n")
            else:
                await client.sock.send("Need to connect before sending messages.\n")
        of "quit":
            await drop_client(client)
        of "":
            await drop_client(client)
        else:
            echo "Unknown command: `" & cmd[0] & "'"


proc handle(client: int) {.async.} =
    while true:
        # If there's no more socket, drop the client
        if not sockets.hasKey(client):
            break
        await process_client(client)


proc register() {.async.} =
    sockets = initTable[int, AsyncSocket]()
    names = initTable[int, string]()

    var server = new_async_socket()
    server.set_sock_opt(OptReuseAddr, true)
    server.bind_addr(Port(3434))
    server.listen()
    while true:
        let sock = await server.accept()
        asyncCheck handle(make_client(sock))


async_check register()
run_forever()