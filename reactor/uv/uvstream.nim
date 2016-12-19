import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/errno
import reactor/async, reactor/util, reactor/datatypes/basic
import posix

type UvStream* = ref object of BytePipe
  inputProvider: ByteOutput
  outputStream: ByteInput
  stream*: ptr uv_stream_t
  writeReq: ptr uv_write_t
  writingNow: uv_buf_t
  #shutdownReq: ptr uv_shutdown_t
  paused: bool
  closed: bool

proc readCb(stream: ptr uv_stream_t, nread: int, buf: ptr uv_buf_t) {.cdecl.} =
  let self = cast[UvStream](stream.data)
  if self.closed: return

  defer:
    if buf.base != nil: dealloc(buf.base)

  if nread == UV_ENOBUFS or self.inputProvider.freeBufferSize == nread:
    checkZero "read_stop", uv_read_stop(stream)
    if nread == UV_ENOBUFS:
      return

  if nread < 0:
    if nread == UV_EOF:
      self.inputProvider.sendClose(JustClose)
    else:
      self.inputProvider.sendClose(uvError(nread, "read stream"))
  else:
    assert nread <= buf.len
    let provided = self.inputProvider.provideSome(ByteView(data: buf.base, size: nread))
    assert provided == nread

proc allocCb(stream: ptr uv_handle_t, suggestedSize: csize, buf: ptr uv_buf_t) {.cdecl.} =
  # TODO: avoid copy (directly point to the queue buffer)
  let self = cast[UvStream](stream.data)

  let size = min(suggestedSize, self.inputProvider.freeBufferSize)
  buf.base = alloc0(size)
  buf.len = size

proc recvStart(self: UvStream) =
  checkZero "read_start", uv_read_start(self.stream, allocCb, readCb)

proc writeReady(self: UvStream)

proc writeCb(req: ptr uv_write_t, status: cint) {.cdecl.} =
  if status == UV_ECANCELED:
    return

  let self = cast[UvStream](req.data)
  if self.closed:
    return

  if status < 0:
    self.inputProvider.sendClose(uvError(status, "stream write"))
  else:
    self.outputStream.discardItems self.writingNow.len
    self.writeReady()

proc freeStream(stream: ptr uv_stream_t) {.cdecl.} =
  freeUvMemory(stream)

proc closeStream(self: UvStream) =
  echo "closing stream"
  self.closed = true
  uv_close(cast[ptr uv_handle_t](self.stream), freeStream)
  self.inputProvider.sendClose(JustClose)
  self.outputStream.recvClose(JustClose)

proc writeReady(self: UvStream) =
  # TODO: write many buffers (peekManyMany?)
  let waiting = self.outputStream.peekMany()

  if self.closed:
    return


  if waiting.len == 0:
    if self.outputStream.isSendClosed:
      logClose(self.outputStream.getSendCloseException)
      closeStream(self)
    else:
      self.outputStream.onRecvReady.addListener proc() = self.writeReady()
  else:
    self.outputStream.onRecvReady.removeAllListeners

    self.writingNow = uv_buf_t(base: waiting.data, len: waiting.size)
    checkZero "write", uv_write(self.writeReq, self.stream, addr self.writingNow, 1, writeCb)

proc resume*(self: UvStream) =
  self.recvStart()

proc newUvStream*[T](stream: ptr uv_stream_t, paused=false): T =
  let self = new(T)
  (self.input, self.inputProvider) = newStreamProviderPair[byte]()
  (self.outputStream, self.output) = newStreamProviderPair[byte]()

  self.stream = stream
  self.paused = paused
  self.writeReq = cast[ptr uv_write_t](newUvReq(UV_WRITE))

  GC_ref(self)
  stream.data = cast[pointer](self)
  self.writeReq.data = cast[pointer](self)

  if not self.paused:
    self.recvStart()

  self.inputProvider.onSendReady.addListener proc() =
    if self.inputProvider.isRecvClosed:
      logClose(self.inputProvider.getRecvCloseException)
      return

    if not self.paused:
      self.recvStart()

  self.outputStream.onRecvReady.addListener proc() =
    self.writeReady()

  return self
