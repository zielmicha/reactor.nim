import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/errno
import reactor/async, reactor/util, collections/views
import posix

type UvPipe* = ref object of BytePipe
  inputOther: ByteOutput
  outputOther: ByteInput
  stream*: ptr uv_stream_t
  writeReq: ptr uv_write_t
  writingNow: uv_buf_t
  #shutdownReq: ptr uv_shutdown_t
  paused: bool
  closed: bool

proc readCb(stream: ptr uv_stream_t, nread: int, buf: ptr uv_buf_t) {.cdecl.} =
  let self = cast[UvPipe](stream.data)
  if self.closed: return

  defer:
    if buf.base != nil: dealloc(buf.base)

  if nread == UV_ENOBUFS or self.inputOther.freeBufferSize == nread:
    checkZero "read_stop", uv_read_stop(stream)
    if nread == UV_ENOBUFS:
      return

  if nread < 0:
    if nread == UV_EOF:
      self.inputOther.sendClose(JustClose)
    else:
      self.inputOther.sendClose(uvError(nread, "read stream"))
  else:
    assert nread <= buf.len
    let sent = self.inputOther.sendSome(ByteView(data: buf.base, size: nread))
    assert sent == nread

proc allocCb(stream: ptr uv_handle_t, suggestedSize: csize, buf: ptr uv_buf_t) {.cdecl.} =
  # TODO: avoid copy (directly point to the queue buffer)
  let self = cast[UvPipe](stream.data)

  let size = min(suggestedSize, self.inputOther.freeBufferSize)
  buf.base = alloc0(size)
  buf.len = size

proc recvStart(self: UvPipe) =
  checkZero "read_start", uv_read_start(self.stream, allocCb, readCb)

proc writeReady(self: UvPipe)

proc writeCb(req: ptr uv_write_t, status: cint) {.cdecl.} =
  if status == UV_ECANCELED:
    return

  let self = cast[UvPipe](req.data)
  if self.closed:
    return

  if status < 0:
    self.inputOther.sendClose(uvError(status, "stream write"))
  else:
    self.outputOther.discardItems self.writingNow.len
    self.writeReady()

proc freeStream(stream: ptr uv_stream_t) {.cdecl.} =
  freeUvMemory(stream)

proc closeStream(self: UvPipe) =
  self.closed = true
  uv_close(cast[ptr uv_handle_t](self.stream), freeStream)
  self.inputOther.sendClose(JustClose)
  self.outputOther.recvClose(JustClose)

proc writeReady(self: UvPipe) =
  # TODO: write many buffers (peekManyMany?)
  let waiting = self.outputOther.peekMany()

  if self.closed:
    return


  if waiting.len == 0:
    if self.outputOther.isSendClosed:
      logClose(self.outputOther.getSendCloseException)
      closeStream(self)
    else:
      self.outputOther.onRecvReady.addListener proc() = self.writeReady()
  else:
    self.outputOther.onRecvReady.removeAllListeners

    self.writingNow = uv_buf_t(base: waiting.data, len: waiting.size)
    checkZero "write", uv_write(self.writeReq, self.stream, addr self.writingNow, 1, writeCb)

proc resume*(self: UvPipe) =
  self.recvStart()

proc newUvPipe*[T](stream: ptr uv_stream_t, paused=false): T =
  let self = new(T)
  (self.input, self.inputOther) = newInputOutputPair[byte]()
  (self.outputOther, self.output) = newInputOutputPair[byte]()

  self.stream = stream
  self.paused = paused
  self.writeReq = cast[ptr uv_write_t](newUvReq(UV_WRITE))

  GC_ref(self)
  stream.data = cast[pointer](self)
  self.writeReq.data = cast[pointer](self)

  if not self.paused:
    self.recvStart()

  self.inputOther.onSendReady.addListener proc() =
    if self.inputOther.isRecvClosed:
      logClose(self.inputOther.getRecvCloseException)
      return

    if not self.paused:
      self.recvStart()

  self.outputOther.onRecvReady.addListener proc() =
    self.writeReady()

  return self
