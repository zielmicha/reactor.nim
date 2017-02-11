import reactor/async, reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream

type FdPipe = ref object of uvstream.UvPipe

proc streamFromFd*(fd: int): BytePipe =
  let pipe = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))

  checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), pipe, 0)
  checkZero "pipe_open", uv_pipe_open(pipe, fd.cint)
  return newUvPipe[FdPipe](cast[ptr uv_stream_t](pipe))
