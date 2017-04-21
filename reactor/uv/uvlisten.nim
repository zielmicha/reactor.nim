import reactor/async
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno

proc serverClosed[ServerType, ConnType](server: ptr uv_stream_t) {.cdecl.} =
  let serverObj = cast[ServerType](server.data)
  GC_unref(serverObj)
  freeUv(server)

proc newListenerServer*[ServerType, ConnType, UvType](server: ptr UvType): ServerType =
  let serverObj = new(ServerType)
  (serverObj.incomingConnections, serverObj.incomingConnectionsProvider) = newInputOutputPair[ConnType]()

  proc closeServer(err: ref Exception) =
    uv_close(cast[ptr uv_handle_t](server), serverClosed[ServerType, ConnType])

  # FIXME: leak
  # serverObj.incomingConnectionsProvider.onRecvClose.addListener closeServer

  GC_ref(serverObj)
  server.data = cast[pointer](serverObj)

  return serverObj

proc onNewConnection*[ServerType, ConnType](server: ptr uv_stream_t; status: cint) {.cdecl.} =
  let serverObj = cast[ServerType](server.data)

  mixin initClient
  var client = initClient(ConnType)
  let err = uv_accept(server, cast[ptr uv_stream_t](client))
  if err != 0:
     echo "Error: failed to accept connection" # FIXME: memory leak etc
     return

  var conn = newUvPipe[ConnType](cast[ptr uv_stream_t](client))

  let provided = serverObj.incomingConnectionsProvider.sendSome(singleItemView(conn))
  if provided == 0:
    stderr.writeLine "Warning: dropped incoming TCP connection"
    # FIXME: don't accept connection if there is no space in the queue
    conn.BytePipe.close(new(CloseException))
