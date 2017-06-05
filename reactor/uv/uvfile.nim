import reactor/util, reactor/async, reactor/uv/uv, reactor/uv/uvutil, os

proc makeReq(callback: proc(req: ptr uv_fs_t)): tuple[req: ptr uv_fs_t, cb: uv_fs_cb] =
  type State = ref object
    callback: proc(req: ptr uv_fs_t)

  let state = new(State)
  state.callback = callback
  let req = cast[ptr uv_fs_t](newUvReq(UV_FS))
  GC_ref(state)
  req.data = cast[pointer](state)

  proc cb(req: ptr uv_fs_t) {.cdecl.} =
    let state = cast[State](req.data)
    state.callback(req)
    freeUv(req)
    GC_unref(state)

  return (req, cb)

type
  FileFlags = distinct cint

  FileFd* = distinct int

let
  Rewrite* = FileFlags(O_TRUNC or O_WRONLY)
  Append* = FileFlags(O_APPEND or O_WRONLY)
  ReadOnly* = FileFlags(O_RDONLY)
  ReadWrite* = FileFlags(O_RDWR)

proc open*(path: string, flags: FileFlags, mode: cint=0o600): Future[FileFd] =
  let completer = newCompleter[FileFd]()

  proc callback(req: ptr uv_fs_t) =
    if req.result < 0:
      completer.completeError(uvError(req.result, "open"))
    else:
      completer.complete(req.result.FileFd)

  let (req, cb) = makeReq(callback)
  let res = uv_fs_open(getThreadUvLoop(), req, path, flags.cint, mode, cb)
  if res < 0:
    completer.completeError(uvError(res, "open"))

  return completer.getFuture()

when not defined(windows):
  import posix, reactor/syscall

  proc setBlocking*(fd: FileFd) =
    var flags = fcntl(fd.cint, F_GETFL, 0);
    if flags == -1:
      raiseOSError(osLastError())

    let r = fcntl(fd.cint, F_SETFL, flags and (not O_NONBLOCK));
    if r == -1:
      raiseOSError(osLastError())

  proc readAsync(fd: cint, buffer: pointer, size: int): Future[int] =
    return spawnSyscall(posix.read(fd, buffer, size))

  proc writeAsync(fd: cint, buffer: pointer, size: int): Future[int] =
    return spawnSyscall(posix.write(fd, buffer, size))

  proc createInputFromFd*(fd: FileFd): ByteInput =
    ## Create ByteInput reading data from a file descriptor. ``fd`` should represent regular file. Do not close ``fd`` manually, it will be closed automaticall.y
    # TODO: use libuv uv_fs_read for better performance
    let (input, output) = newInputOutputPair[byte]()

    proc piper() {.async.} =
      var buffer = newString(40960)
      setBlocking(fd)
      defer: discard close(fd.cint)
      while true:
        await output.waitForSpace
        let readSize = min(output.freeBufferSize, buffer.len)
        let count = await readAsync(fd.cint, addr buffer[0], readSize)
        assert count >= 0
        if count == 0:
          break
        let sent = output.sendSome(buffer.stringView.slice(0, count))
        assert sent == count

      output.sendClose(JustClose)

    piper().onErrorClose(output)
    return input

  proc createOutputFromFd*(fd: FileFd): ByteOutput =
    ## Create ByteOutput writing data to a file descriptor. ``fd`` should represent regular file. Do not close ``fd`` manually, it will be closed automaticall.y
    # TODO: use libuv uv_fs_write for better performance
    let (input, output) = newInputOutputPair[byte]()

    proc piper() {.async.} =
      var buffer = newString(40960)
      setBlocking(fd)
      # TODO: defer: close(fd)
      while true:
        await input.waitForData
        let data = input.peekMany
        let count = await writeAsync(fd.cint, data.data, data.len)
        assert count >= 0
        input.discardItems(count)

      input.recvClose(JustClose)

    piper().onErrorClose(input)
    return output
