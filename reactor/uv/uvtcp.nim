import reactor/util
import reactor/loop
import reactor/async
import reactor/resolv
import reactor/ipaddress
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno

when defined(windows):
  import winlean
else:
  import posix

type
  TcpServer* = ref object
    incomingConnections*: Stream[TcpConnection]
    incomingConnectionsProvider: Provider[TcpConnection]

  TcpConnection* = ref object of uvstream.UvStream

export UvStream

proc newTcpConnection(client: ptr uv_handle_t): TcpConnection =
  return newUvStream[TcpConnection](cast[ptr uv_stream_t](client))

proc getPeerAddr*(conn: TcpConnection): tuple[address: IpAddress, port: int] =
  ## Get address of a remote peer (similar to POSIX getpeername).
  var name: SockAddr
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
    stderr.writeLine "Warning: dropped incoming TCP connection"
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

  # TODO: serverObj.incomingConnectionsProvider.onRecvClose.addListener closeTcpServer

  GC_ref(serverObj)
  server.data = cast[pointer](serverObj)

  return serverObj

proc createTcpServer*(port: int, host="localhost"): Future[TcpServer] =
  ## Create TcpServer listening on `host`:`port`.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##   let server = await createTcpServer(5000)
  ##   asyncFor conn in server.incomingConnections:
  ##     # handle incoming connection
  ##     await conn.output.write("hello")
  let server = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))
  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), server)

  proc resolved(addresses: seq[IpAddress]): Future[TcpServer] =
    for address in addresses:
      var sockaddress: SockAddr
      ipaddrToSockaddr(cast[ptr SockAddr](addr sockaddress), address, port)
      let bindErr = uv_tcp_bind(server, cast[ptr SockAddr](addr sockaddress), 0)
      if bindErr == UV_ENOPROTOOPT: # FIXME: windows
        continue
      if bindErr < 0:
        return now(error(TcpServer, uvError(bindErr, "bind [" & $address & "]:" & $port)))
      else:
        break

    let serverObj = newTcpServer(server)

    let listenErr = uv_listen(cast[ptr uv_stream_t](server), 5, onNewConnection)
    if listenErr < 0:
      return now(error(TcpServer, uvError(listenErr, "listen")))

    return now(just(serverObj))

  return resolveAddress(host).then(resolved)

proc connectTcp*(host: IpAddress, port: int): Future[TcpConnection] =
  ## Connect to TCP server running on host:port.
  let connectReq = cast[ptr uv_connect_t](newUvReq(UV_CONNECT))

  type State = ref object
    completer: Completer[TcpConnection]
    sockaddress: ptr SockAddr
    errMsg: string

  let state = State(completer: newCompleter[TcpConnection]())
  GC_ref(state)
  connectReq.data = cast[pointer](state)
  state.sockaddress = cast[ptr SockAddr](alloc0(SockAddr_maxsize))
  ipaddrToSockaddr(state.sockaddress, host, port)

  state.errMsg = "connect to [" & $host & "]:" & $port

  proc connectCb(req: ptr uv_connect_t, status: cint) {.cdecl.} =
    let state = cast[State](req.data)
    if status < 0:
      state.completer.completeError(uvError(status, state.errMsg))
      uv_close(req.handle, freeUvMemory)
    else:
      state.completer.complete(newUvStream[TcpConnection](req.handle))

    dealloc(state.sockaddress)
    GC_unref(state)

  let handle = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))
  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), handle)
  let ret = uv_tcp_connect(connectReq, handle, state.sockaddress, connectCb)
  if ret < 0:
    return now(error(TcpConnection, uvError(ret, state.errMsg)))
  else:
    return state.completer.getFuture

proc connectTcp*(host: string, port: int): Future[TcpConnection] {.async.} =
  ## Connect to TCP server running on host:port.
  # TODO: add bindHost

  let addresses = await resolveAddress(host)
  if addresses.len == 0:
    asyncRaise "no address resolved"
  else: # TODO: iterate over addresses
    return (await connectTcp(addresses[0], port))

proc close*(t: TcpConnection, err: ref Exception) =
  ## Close TCP connection.
  # why close doesn't work without this?
  BytePipe(t).close(err)
