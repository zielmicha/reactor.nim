import reactor/util
import reactor/loop
import reactor/async
import reactor/resolv
import reactor/ipaddress
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno
import options

when defined(windows):
  import winlean
else:
  import posix

type
  TcpServer* = ref object
    incomingConnections*: Stream[TcpConnection]
    incomingConnectionsProvider: Provider[TcpConnection]
    sockAddr: tuple[address: IpAddress, port: int]

  TcpConnection* = ref object of uvstream.UvStream

  TcpConnectionData* = object
    host*: IpAddress
    # IP address

    port*: int
    # TCP port

    boundSocket*: TcpBoundSocket
    # if not nil, use pre-existing bound TCP socket

  TcpBoundSocket* = ref object
    stream: ptr uv_tcp_t

export UvStream

proc newTcpConnection(client: ptr uv_handle_t): TcpConnection =
  return newUvStream[TcpConnection](cast[ptr uv_stream_t](client))

proc getPeerAddr*(conn: TcpConnection): tuple[address: IpAddress, port: int] =
  ## Get address of a remote peer (similar to POSIX getpeername).
  var name: SockAddr_storage
  var length = sizeof(name).cint
  checkZero "getpeername", uv_tcp_getpeername(conn.stream, cast[ptr SockAddr](addr name), addr length)
  return sockaddrToIpaddr(cast[ptr SockAddr](addr name))

proc getSockAddr(stream: ptr uv_stream_t): tuple[address: IpAddress, port: int] =
  ## Get address of a TCP socket (similar to POSIX getsockname).
  var name: SockAddr_storage
  var length = sizeof(name).cint
  checkZero "getsockname", uv_tcp_getsockname(stream, cast[ptr SockAddr](addr name), addr length)
  return sockaddrToIpaddr(cast[ptr SockAddr](addr name))

proc getSockAddr*(conn: TcpBoundSocket | TcpConnection): tuple[address: IpAddress, port: int] =
  return getSockAddr(conn.stream)

proc getSockAddr*(conn: TcpServer): auto =
  return conn.sockAddr

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

  # FIXME: leak
  # serverObj.incomingConnectionsProvider.onRecvClose.addListener closeTcpServer

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
    serverObj.sockAddr = getSockAddr(server) # for getSockAddr

    let listenErr = uv_listen(cast[ptr uv_stream_t](server), 5, onNewConnection)
    if listenErr < 0:
      return now(error(TcpServer, uvError(listenErr, "listen")))

    return now(just(serverObj))

  return resolveAddress(host).then(resolved)

proc bindSocketForConnect*(bindHost: IpAddress, bindPort: int): Future[TcpBoundSocket] =
  let handle = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))

  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), handle)

  var sockaddress: SockAddr
  ipaddrToSockaddr(cast[ptr SockAddr](addr sockaddress),
                   bindHost,
                   bindPort)

  let bindRet = uv_tcp_bind(handle, cast[ptr SockAddr](addr sockaddress), 0)
  if bindRet < 0:
    uv_close(handle, freeUvMemory)
    return now(error(TcpBoundSocket,
                     uvError(bindRet, "bind [" & $bindHost & "]:" & $bindPort)))
  else:
    return now(just(TcpBoundSocket(stream: handle)))

proc connectTcpAsHandle(info: TcpConnectionData): Future[ptr uv_stream_t] =
  ## Connect to TCP server running on host:port.

  var handle: ptr uv_tcp_t

  if info.boundSocket == nil:
    handle = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))
    checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), handle)
  else:
    handle = info.boundSocket.stream
    info.boundSocket.stream = nil

  type State = ref object
    completer: Completer[ptr uv_stream_t]
    sockaddress: ptr SockAddr
    errMsg: string

  let connectReq = cast[ptr uv_connect_t](newUvReq(UV_CONNECT))

  let state = State(completer: newCompleter[ptr uv_stream_t]())
  connectReq.data = cast[pointer](state)
  state.sockaddress = cast[ptr SockAddr](alloc0(SockAddr_maxsize))
  ipaddrToSockaddr(state.sockaddress, info.host, info.port)

  state.errMsg = "connect to [" & $info.host & "]:" & $info.port

  proc connectCb(req: ptr uv_connect_t, status: cint) {.cdecl.} =
    let state = cast[State](req.data)
    if status < 0:
      state.completer.completeError(uvError(status, state.errMsg))
      uv_close(req.handle, freeUvMemory)
    else:
      state.completer.complete(req.handle)

    dealloc(state.sockaddress)
    GC_unref(state)

  GC_ref(state)
  let ret = uv_tcp_connect(connectReq, handle, state.sockaddress, connectCb)
  if ret < 0:
    # FIXME: should we deallocate here or callback will be called?
    return now(error(ptr uv_stream_t, uvError(ret, state.errMsg)))
  else:
    return state.completer.getFuture

proc connectTcp*(info: TcpConnectionData): Future[TcpConnection] =
  return connectTcpAsHandle(info).then(x => newUvStream[TcpConnection](x))

proc connectTcp*(host: IpAddress, port: int): Future[TcpConnection] =
  return connectTcp(TcpConnectionData(host: host, port: port))

when not defined(windows):
  import posix

  proc handleToFd(s: ptr uv_stream_t): cint =
    var fd: cint
    checkZero "uv_fileno", uv_fileno(cast[ptr uv_handle_t](s), addr fd)
    result = dup(fd)
    uv_close(cast[ptr uv_handle_t](s), freeUvMemory)

  proc connectTcpAsFd*(info: TcpConnectionData): Future[cint] =
    ## Connect to TCP server running on host:port.
    return connectTcpAsHandle(info).then(handleToFd)

proc connectTcp*(host: string, port: int): Future[TcpConnection] {.async.} =
  ## Connect to TCP server running on host:port.
  let addresses = await resolveAddress(host)
  if addresses.len == 0:
    asyncRaise "no address resolved"
  else: # TODO: iterate over addresses
    return (await connectTcp(addresses[0], port))

proc close*(t: TcpConnection, err: ref Exception) =
  ## Close TCP connection.
  # why close doesn't work without this?
  BytePipe(t).close(err)
