import asyncnet, asyncdispatch, sequtils, strutils, locks

type
    StateKind = enum Connected, Anonymous
    State = ref object
        case kind : StateKind:
        of Connected: name : string
        of Anonymous: nil

type Client = tuple[state: State, sock:AsyncSocket]

type delta_kind = enum ChangeName, None
type delta = ref object
    case kind: delta_kind
    of ChangeName:
        client: Client
        name : string
    of None: nil


var clients {.threadvar.}: seq[Client]
var clients_lock: Lock

proc process_cmd(client: Client, cmd:seq[string]) : delta =
     case cmd[0]:
         of "CONNEXION":
             echo("Incoming connexion")
             result = delta(kind:ChangeName, client:client, name:cmd[1])
         else:
             echo "Unknown command"
             result = delta(kind:None)


proc process_client(client: Client) : Future[delta] {.async.} =
    while true:
        let line = await client.sock.recv_line()
        echo line
        if line.len == 0:
            echo("empty line")
            break
        let delta = client.process_cmd(line.split({'/'}))
        if delta.kind == ChangeName:
            echo("Change name!")
        # Shouldn't return, but pass a message.
        return delta

proc serve() {.async.} =
    clients = @[]
    var server = new_async_socket()
    server.set_sock_opt(OptReuseAddr, true)
    server.bind_addr(Port(3434))
    server.listen()

    while true:
        let sock = await server.accept()
        let client = Client((State(kind:Anonymous), sock))
        clients.add client
        let delta = await process_client(client)
        if delta.kind == ChangeName:
            echo "go changed name"
            # acquire clients_lock
            clients.keepIf(proc (c:Client) : bool = c == delta.client)
            # release clients_lock
            for client in clients:
                await client.sock.send(delta.name & "connected.")
        else:
            echo "got nothing"


async_check serve()
run_forever()