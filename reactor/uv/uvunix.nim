# implements Unix sockets
import reactor/util
import reactor/loop
import reactor/async
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno, reactor/uv/uvlisten, posix

type
  UnixConnection* = ref object of uvstream.UvPipe

  UnixServer* = ref object of Server[UnixServer, UnixConnection]
    allowFdPassing: bool

export incomingConnections, accept, acceptAsFd

proc connectUnix*(path: string, allowFdPassing=false): Future[UnixConnection] =
  ## Connect to TCP server running on host:port.
  let connectReq = cast[ptr uv_connect_t](newUvReq(UV_CONNECT))

  type State = ref object
    completer: Completer[UnixConnection]
    errMsg: string

  let state = State(completer: newCompleter[UnixConnection]())
  GC_ref(state)
  connectReq.data = cast[pointer](state)

  state.errMsg = "connect to " & $path

  proc connectCb(req: ptr uv_connect_t, status: cint) {.cdecl.} =
    let state = cast[State](req.data)
    if status < 0:
      state.completer.completeError(uvError(status, state.errMsg))
      uv_close(req.handle, freeUvMemory)
    else:
      state.completer.complete(newUvPipe[UnixConnection](req.handle))

    freeUvMemory(cast[ptr uv_handle_t](req))
    GC_unref(state)

  let handle = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), handle, if allowFdPassing: 1.cint else: 0.cint)
  uv_pipe_connect(connectReq, handle, $path, connectCb)
  return state.completer.getFuture

proc initClient(self: UnixServer): ptr uv_tcp_t =
  result = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), result, if self.allowFdPassing: 1.cint else: 0.cint)

proc createUnixServer*(path: string, allowFdPassing=false, reuse=true): UnixServer =
  assert len(path) < 92

  if reuse:
    var s: Stat
    if stat(path, s) == 0 and S_ISSOCK(s.st_mode):
      discard unlink(path)

  let server = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), server, if allowFdPassing: 1.cint else: 0.cint)
  let bindErr = uv_pipe_bind(server, path)
  if bindErr < 0: raise uvError(bindErr, "bind")

  let serverObj = newListenerServer[UnixServer, UnixConnection, uv_pipe_t](server)
  serverObj.allowFdPassing = allowFdPassing
  let listenErr = uv_listen(cast[ptr uv_stream_t](server), 5, onNewConnection[UnixServer, UnixConnection])
  if listenErr < 0: raise uvError(listenErr, "listen")

  return serverObj

proc getPendingFds*(self: UnixConnection): int =
  return uv_pipe_pending_count(self.stream)

proc acceptFd*(self: UnixConnection): Future[cint] =
  if getPendingFds(self) == 0:
    raise newException(IOError, "no pending FDs")

  let kind = uv_pipe_pending_type(self.stream)
  var handle: pointer
  if kind == UV_TCP:
    handle = newUvHandle(UV_TCP)
    checkZero "tcp_init", uv_tcp_init(getThreadUvLoop(), cast[ptr uv_tcp_t](handle))
  elif kind == UV_NAMED_PIPE:
    handle = newUvHandle(UV_NAMED_PIPE)
    checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), cast[ptr uv_pipe_t](handle), 0)
  else:
    raise newException(IOError, "unknown fd type " & $kind)

  if uv_accept(self.stream, cast[ptr uv_stream_t](handle)) != 0:
    uv_close(cast[ptr uv_handle_t](self.stream), freeUvMemory)
    raise newException(IOError, "failed to accept fd")

  let fd = handleToFd(cast[ptr uv_stream_t](handle))
  return now(just(fd))

proc sendFd*(self: UnixConnection, fd: cint, message: string): Future[void] =
  let pipe = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))

  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), pipe, 1)
  checkZero "pipe_open", uv_pipe_open(pipe, fd.cint)

  let msg = new(string)
  msg[] = message
  GC_ref(msg)

  proc writeCb(req: ptr uv_write_t, status: cint) {.cdecl.} =
    GC_unref(cast[ref string](req.data))
    freeUvMemory(cast[ptr uv_handle_t](req))

  let writeReq = cast[ptr uv_write_t](newUvReq(UV_WRITE))
  writeReq.data = cast[pointer](msg)

  var buf = uv_buf_t(base: addr msg[][0], len: msg[].len)
  checkZero "write", uv_write2(writeReq, self.stream, addr buf, 1,
                               cast[ptr uv_stream_t](pipe), writeCb)
  return now(just())
