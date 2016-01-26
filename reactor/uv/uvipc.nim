import reactor/async, reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/uv/uvmsgstream, reactor/uv/errno

export newMsgPipe, MsgPipe

type
  IpcPipe* = ref object of uvstream.UvStream

proc fromPipeFd*(fd: cint, ipc=false): IpcPipe =
  let handle = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), handle, if ipc: 1 else: 0)
  checkZero "pipe_open", uv_pipe_open(handle, fd)
  return newUvStream[IpcPipe](cast[ptr uv_stream_t](handle))

proc fileno*(p: IpcPipe): cint =
  checkZero "fileno", uv_fileno(p.stream, addr result)

proc getPendingHandle*(p: IpcPipe, ipc=false, paused=false): Future[IpcPipe] =
  let handle = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))
  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), handle, if ipc: 1 else: 0)

  if uv_accept(cast[ptr uv_handle_t](p.stream), cast[ptr uv_stream_t](handle)) == 0:
    return newUvStream[IpcPipe](cast[ptr uv_stream_t](handle), paused=paused).immediateFuture
  else:
    return immediateError[IpcPipe]("receive file handle")
