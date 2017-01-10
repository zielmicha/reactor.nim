# implements Unix sockets
import reactor/util
import reactor/loop
import reactor/async
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/errno

type
  UnixConnection* = ref object of uvstream.UvStream

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
      state.completer.complete(newUvInput[UnixConnection](req.handle))

    GC_unref(state)

  let handle = cast[ptr uv_pipe_t](newUvHandle(UV_TCP))
  checkZero "tcp_init", uv_pipe_init(getThreadUvLoop(), handle, 0)
  uv_pipe_connect(connectReq, handle, $path, connectCb)
  return state.completer.getFuture
