import reactor/async
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno

type Server*[ServerType, ConnType] = ref object of RootObj
  connections*: Pipe[ptr uv_stream_t]
  serverHandle: ptr uv_handle_t

proc serverClosed[ServerType, ConnType](server: ptr uv_stream_t) {.cdecl.} =
  let serverObj = cast[ServerType](server.data)
  GC_unref(serverObj)
  freeUv(server)

proc close*[ServerType, ConnType](self: Server[ServerType, ConnType]) =
  if self.serverHandle != nil:
    self.connections.output.sendClose JustClose
    uv_close(cast[ptr uv_handle_t](self.serverHandle), serverClosed[ServerType, ConnType])
    self.serverHandle = nil

proc newListenerServer*[ServerType, ConnType, UvType](server: ptr UvType): ServerType =
  let serverObj = new(ServerType)

  GC_ref(serverObj)
  server.data = cast[pointer](serverObj)
  serverObj.serverHandle = cast[ptr uv_handle_t](server)
  serverObj.connections = newPipe(newInputOutputPair[ptr uv_stream_t]())

  return serverObj

proc onNewConnection*[ServerType, ConnType](server: ptr uv_stream_t; status: cint) {.cdecl.} =
  let self = cast[ServerType](server.data)

  mixin initClient
  var client = initClient(ConnType)
  let err = uv_accept(server, cast[ptr uv_stream_t](client))
  if err != 0:
    echo "Error: failed to accept connection" # FIXME: memory leak etc
    return

  var clientV = cast[ptr uv_stream_t](client)
  let p = self.connections.output.sendSome singleItemView(clientV)
  if p != 1:
    echo "Error: TCP connection buffer full"
    uv_close(cast[ptr uv_handle_t](client), freeUvMemory)
    return

proc acceptRaw[ServerType, ConnType](self: Server[ServerType, ConnType]): Future[ptr uv_stream_t] =
  return self.connections.input.receive

proc acceptAsFd*[ServerType, ConnType](self: Server[ServerType, ConnType]): Future[cint] =
  return self.acceptRaw().then(handleToFd)

proc accept*[ServerType, ConnType](self: Server[ServerType, ConnType]): Future[ConnType] =
  return self.acceptRaw().then(proc(t: ptr uv_stream_t): ConnType = newUvPipe[ConnType](t))

proc incomingConnections*[ServerType, ConnType](self: Server[ServerType, ConnType]): Input[ConnType] {.asynciterator.} =
  while true:
    let conn = await self.accept()
    asyncYield conn
