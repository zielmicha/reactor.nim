import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/errno
import reactor/async, reactor/util, collections/views

type MsgPipe* = ref object of Pipe[string]
  mOutput: Output[string]
  mInput: Input[string]
  stream*: ptr uv_stream_t
  buffer: string
  writeReq: ptr uv_write_t
  writingNow: uv_buf_t
  shutdownReq: ptr uv_shutdown_t
  sendClosed: bool
  paused: bool

proc readCb(stream: ptr uv_stream_t, nread: int, buf: ptr uv_buf_t) {.cdecl.} =
  let self = cast[MsgPipe](stream.data)

  if self.mOutput.freeBufferSize == 1:
    checkZero "read_stop", uv_read_stop(stream)
    if nread == UV_ENOBUFS:
      return

  if nread < 0:
    self.mOutput.sendClose(uvError(nread, "read stream"))
  else:
    if self.sendClosed:
      return

    assert nread <= self.buffer.len
    var data = self.buffer[0..<nread]
    data.shallow
    let provided = self.mOutput.sendSome(unsafeInitView(addr data, 1))
    assert provided == 1

proc allocCb(stream: ptr uv_handle_t, suggestedSize: csize, buf: ptr uv_buf_t) {.cdecl.} =
  let self = cast[MsgPipe](stream.data)

  buf.base = self.buffer.cstring
  buf.len = self.buffer.len

proc recvStart(self: MsgPipe) =
  checkZero "read_start", uv_read_start(self.stream, allocCb, readCb)

proc writeReady(self: MsgPipe)

proc writeCb(req: ptr uv_write_t, status: cint) {.cdecl.} =
  let self = cast[MsgPipe](req.data)

  if status < 0:
    self.mOutput.sendClose(uvError(status, "stream write"))
    self.sendClosed = true
  else:
    self.mInput.discardItems(1)
    self.writeReady()

proc writeReady(self: MsgPipe) =
  let waiting = self.mInput.peekMany()

  if waiting.len == 0:
    self.mInput.onRecvReady.addListener proc() = self.writeReady()
  else:
    self.mInput.onRecvReady.removeAllListeners

    self.writingNow = uv_buf_t(base: waiting[0].cstring, len: waiting[0].len)
    checkZero "write", uv_write(self.writeReq, self.stream, addr self.writingNow, 1, writeCb)

proc resume*(self: MsgPipe) =
  self.recvStart()

proc newMsgPipe*(fileno: cint): MsgPipe =
  # TODO: onClose!!!
  let self = new(MsgPipe)
  (self.mInput, self.output) = newInputOutputPair[string]()
  (self.input, self.mOutput) = newInputOutputPair[string]()

  self.stream = cast[ptr uv_stream_t](newUvHandle(UV_TTY))
  checkZero "tty_init", uv_tty_init(getThreadUvLoop(), cast[ptr uv_tty_t](self.stream), fileno, 1.cint)
  #checkZero "tty_set_mode", uv_tty_set_mode(cast[ptr uv_tty_t](self.stream), UV_TTY_MODE_IO)
  self.writeReq = cast[ptr uv_write_t](newUvReq(UV_WRITE))

  GC_ref(self)
  self.stream.data = cast[pointer](self)
  self.writeReq.data = cast[pointer](self)
  self.buffer = newString(65636)

  self.recvStart()

  self.mOutput.onSendReady.addListener proc() =
    self.recvStart()

  self.mInput.onRecvReady.addListener proc() = self.writeReady()

  return self
