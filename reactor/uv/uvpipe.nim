# included from reactor/file.nim
import reactor/async, reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvstream, reactor/file, posix

type FdPipe = ref object of uvstream.UvPipe

proc streamFromFd*(fd: cint): BytePipe =
  let pipe = cast[ptr uv_pipe_t](newUvHandle(UV_NAMED_PIPE))

  let kind = uv_guess_handle(cint(fd)).uv_handle_type

  # we can safely epoll these
  if kind in {UV_TTY, UV_NAMED_PIPE, UV_TCP}:
    checkZero "pipe_init", uv_pipe_init(getThreadUvLoop(), pipe, 0)
    checkZero "pipe_open", uv_pipe_open(pipe, fd.cint)
    return newUvPipe[FdPipe](cast[ptr uv_stream_t](pipe))
  else:
    let inFd = dupCloexec(fd)
    return BytePipe(
      input: createInputFromFd(inFd),
      output: createOutputFromFd(fd),
    )

proc closeFd*(fd: cint) =
  if close(fd) != 0:
    raiseOSError(osLastError())
