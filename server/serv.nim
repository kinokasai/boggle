import asyncnet, asyncdispatch

var clients {.threadvar.}: seq[AsyncSocket]

proc process_client(client: AsyncSocket) {.async.} =
    while true:
        let line = await client.recv_line()
        if line.len == 0: break
        for c in clients:
            if c == client:
                continue
            await c.send(line & "\c\L")

proc serve() {.async.} =
    clients = @[]
    var server = new_async_socket()
    server.set_sock_opt(OptReuseAddr, true)
    server.bind_addr(Port(3434))
    server.listen()

    while true:
        let client = await server.accept()
        clients.add client

        async_check process_client(client)

async_check serve()
run_forever()