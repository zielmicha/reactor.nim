import reactor/util
import reactor/loop
import reactor/async
import reactor/resolv
import reactor/ipaddress
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno
import posix

type
  TcpServer* = ref object
    incomingConnections*: Stream[TcpConnection]
    incomingConnectionsProvider: Provider[TcpConnection]

  TcpConnection* = ref object of uvstream.UvStream

proc newTcpConnection*(client: ptr uv_handle_t): TcpConnection =
  return newUvStream[TcpConnection](cast[ptr uv_stream_t](client))

proc getPeerAddr*(conn: TcpConnection): tuple[address: IpAddress, port: int] =
  var name: Sockaddr_storage
  var length = sizeof(name).cint
  checkZero "getpeername", uv_tcp_getpeername(conn.stream, cast[ptr SockAddr](addr name), addr length)
  return sockaddrToIpaddr(cast[ptr SockAddr](addr name))

proc onNewConnection(server: ptr uv_stream_t; status: cint) {.cdecl.} =
  let serverObj = cast[TcpServer](server.data)

  var client = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))
  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), client)
  let err = uv_accept(server, cast[ptr uv_stream_t](client))
  if err != 0:
     echo "Error: failed to accept connection" # FIXME: memory leak etc
     return

  var conn = newTcpConnection(client)

  let provided = serverObj.incomingConnectionsProvider.provideSome(singleItemView(conn))
  if provided == 0:
    # FIXME: don't accept connection if there is no space in the queue
    conn.BytePipe.close(new(CloseException))

proc tcpServerClosed(server: ptr uv_stream_t) {.cdecl.} =
  let serverObj = cast[TcpServer](server.data)
  GC_unref(serverObj)
  freeUv(server)

proc newTcpServer(server: ptr uv_tcp_t): TcpServer =
  let serverObj = new(TcpServer)
  (serverObj.incomingConnections, serverObj.incomingConnectionsProvider) = newStreamProviderPair[TcpConnection]()

  proc closeTcpServer(err: ref Exception) =
    uv_close(cast[ptr uv_handle_t](server), tcpServerClosed)

  serverObj.incomingConnectionsProvider.onRecvClose = closeTcpServer

  GC_ref(serverObj)
  server.data = cast[pointer](serverObj)

  return serverObj

proc createTcpServer*(port: int, host="localhost"): Future[TcpServer] =
  let server = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))
  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), server)

  proc resolved(addresses: seq[IpAddress]): Future[TcpServer] =
    for address in addresses:
      var sockaddress: Sockaddr_storage
      ipaddrToSockaddr(cast[ptr SockAddr](addr sockaddress), address, port)
      let bindErr = uv_tcp_bind(server, cast[ptr SockAddr](addr sockaddress), 0)
      if bindErr == UV_ENOPROTOOPT: # FIXME: windows
        continue
      if bindErr < 0:
        return immediateError[TcpServer](uvError(bindErr, "bind [" & $address & "]:" & $port))

    let serverObj = newTcpServer(server)

    let listenErr = uv_listen(cast[ptr uv_stream_t](server), 5, onNewConnection)
    if listenErr < 0:
      return immediateError[TcpServer](uvError(listenErr, "listen"))

    return immediateFuture(serverObj)

  return resolveAddress(host).then(resolved)
