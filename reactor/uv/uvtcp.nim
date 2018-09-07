import reactor/util
import reactor/loop
import reactor/async
import reactor/resolv
import reactor/ipaddress
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno
import reactor/uv/uvlisten
import options

when defined(windows):
  import winlean
else:
  import posix

type
  TcpServer* = ref object of uvlisten.Server[TcpServer, TcpConnection]
    sockAddr: InetAddress

  TcpConnection* = ref object of uvstream.UvPipe

  TcpConnectionData* = object
    host*: IpAddress
    ## IP address

    port*: int
    ## TCP port

    boundSocket*: TcpBoundSocket
    ## if not nil, use pre-existing bound TCP socket

  TcpBoundSocket* = ref object
    stream: ptr uv_tcp_t

export UvStream, incomingConnections, acceptAsFd, accept, close

proc getPeerAddr*(fd: cint): InetAddress =
  ## Get address of a remote peer (similar to POSIX getpeername).
  var name: SockAddr_storage
  var length = sizeof(name).Socklen
  checkZero "getpeername", getpeername(SocketHandle(fd), cast[ptr SockAddr](addr name), addr length)
  return sockaddrToIpaddr(cast[ptr SockAddr](addr name))

proc getPeerAddr*(conn: TcpConnection): InetAddress =
  ## Get address of a remote peer (similar to POSIX getpeername).
  var name: SockAddr_storage
  var length = sizeof(name).cint
  checkZero "getpeername", uv_tcp_getpeername(conn.stream, cast[ptr SockAddr](addr name), addr length)
  return sockaddrToIpaddr(cast[ptr SockAddr](addr name))

proc getSockAddr(stream: ptr uv_stream_t): InetAddress =
  ## Get address of a TCP socket (similar to POSIX getsockname).
  var name: SockAddr_storage
  var length = sizeof(name).cint
  checkZero "getsockname", uv_tcp_getsockname(stream, cast[ptr SockAddr](addr name), addr length)
  return sockaddrToIpaddr(cast[ptr SockAddr](addr name))

proc getSockAddr*(conn: TcpBoundSocket | TcpConnection): InetAddress =
  return getSockAddr(conn.stream)

proc getSockAddr*(conn: TcpServer): auto =
  return conn.sockAddr

proc initClient(self: TcpServer): ptr uv_tcp_t =
  result = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))
  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), result)
  checkZero "tcp_nodelay", uv_tcp_nodelay(result, 1)

let localhostAddresses* = @[
  parseAddress("127.0.0.1"),
  parseAddress("::1"),
]

proc createTcpServer*(port: int, addresses: seq[IpAddress], reusePort=false): Future[TcpServer] =
  let server = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))
  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), server)

  if addresses.len == 0:
    return now(error(TcpServer, "no IP address"))

  for address in addresses:
    var sockaddress: SockAddr_storage
    ipaddrToSockaddr(cast[ptr SockAddr](addr sockaddress), address, port)
    let flags = if reusePort: cuint(UV_TCP_REUSEPORT)
                else: cuint(0)
    let bindErr = uv_tcp_bind(server, cast[ptr SockAddr](addr sockaddress), flags)
    if bindErr == UV_ENOPROTOOPT: # FIXME: windows
      continue
    if bindErr < 0:
      return now(error(TcpServer, uvError(bindErr, "bind [" & $address & "]:" & $port)))
    else:
      break

  let serverObj = newListenerServer[TcpServer, TcpConnection, uv_tcp_t](server)
  serverObj.sockAddr = getSockAddr(server) # for getSockAddr

  let listenErr = uv_listen(cast[ptr uv_stream_t](server), 5, onNewConnection[TcpServer, TcpConnection])
  if listenErr < 0:
    return now(error(TcpServer, uvError(listenErr, "listen")))

  return now(just(serverObj))

proc createTcpServer*(port: int, reusePort=false): Future[TcpServer] =
  return createTcpServer(port, localhostAddresses, reusePort)

proc createTcpServer*(port: int, host: string, reusePort=false): Future[TcpServer] =
  ## Create TcpServer listening on `host`:`port`.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##   let server = await createTcpServer(5000)
  ##   asyncFor conn in server.incomingConnections:
  ##     # handle incoming connection
  ##     await conn.output.write("hello")
  return resolveAddress(host).then(addresses => createTcpServer(port, addresses, reusePort))

proc bindSocketForConnect*(bindHost: IpAddress, bindPort: int): Future[TcpBoundSocket] =
  let handle = cast[ptr uv_tcp_t](newUvHandle(UV_TCP))

  checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), handle)
  checkZero "tcp_nodelay", uv_tcp_nodelay(handle, 0)
  checkZero "tcp_keepalive", uv_tcp_keepalive(handle, 1, 55)

  var sockaddress: SockAddr_storage
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
    checkZero "tcp_nodelay", uv_tcp_nodelay(handle, 0)
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
  return connectTcpAsHandle(info).then(x => newUvPipe[TcpConnection](x))

proc connectTcp*(host: IpAddress, port: int): Future[TcpConnection] =
  return connectTcp(TcpConnectionData(host: host, port: port))

when not defined(windows):
  import posix

  proc connectTcpAsFd*(info: TcpConnectionData): Future[cint] =
    ## Connect to TCP server running on host:port.
    return connectTcpAsHandle(info).then(handleToFd)

  proc connectTcpAsFd*(host: IpAddress, port: int): Future[cint] =
    ## Connect to TCP server running on host:port.
    return connectTcpAsFd(TcpConnectionData(host: host, port: port))

proc connectTcp*(host: string, port: int): Future[TcpConnection] {.async.} =
  ## Connect to TCP server running on host:port.
  let addresses = await resolveAddress(host)
  if addresses.len == 0:
    asyncRaise "no address resolved"
  else: # TODO: iterate over addresses
    return (await connectTcp(addresses[0], port))

proc close*(t: TcpConnection, err: ref Exception=JustClose) =
  ## Close TCP connection.
  # why close doesn't work without this?
  BytePipe(t).close(err)
