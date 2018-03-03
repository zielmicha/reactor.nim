# implements Unix sockets
import reactor/util
import reactor/loop
import reactor/async
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno, reactor/uv/uvlisten

type
  UnixConnection* = ref object of uvstream.UvPipe

  UnixServer* = ref object of Server[UnixServer, UnixConnection]

export incomingConnections, accept, acceptAsFd

proc connectUnix*(path: string): Future[UnixConnection] =
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

    GC_unref(state)

  let handle = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), handle, 0)
  uv_pipe_connect(connectReq, handle, $path, connectCb)
  return state.completer.getFuture

proc initClient(t: typedesc[UnixConnection]): ptr uv_tcp_t =
  result = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), result, 0)

proc createUnixServer*(path: string): UnixServer =
  assert len(path) < 92
  let server = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), server, 0.cint)
  let bindErr = uv_pipe_bind(server, path)
  if bindErr < 0: raise uvError(bindErr, "bind")

  let serverObj = newListenerServer[UnixServer, UnixConnection, uv_pipe_t](server)
  let listenErr = uv_listen(cast[ptr uv_stream_t](server), 5, onNewConnection[UnixServer, UnixConnection])
  if listenErr < 0: raise uvError(listenErr, "listen")

  return serverObj
