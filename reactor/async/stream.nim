# included from reactor/async.nim

type
  BufferedInput*[T] = ref object
    bufferSize: int
    queue: Queue[T]

    onRecvReady: Event[void]
    onSendReady: Event[void]
    sendClosed: bool
    recvClosed: bool
    sendCloseException: ref Exception
    recvCloseException: ref Exception

    when not defined(release):
      marker: uint32 # has to be 0xDEADBEEF

  BufferedOutput* {.borrow: `.`.}[T]  = distinct BufferedInput[T]

  Input*[T] = BufferedInput[T]
  Output*[T] = BufferedOutput[T]

  BufferedPipe*[T] = ref object {.inheritable.}
    input*: BufferedInput[T]
    output*: BufferedOutput[T]

  Pipe*[T] = BufferedPipe[T]

  CloseException* = object of Exception
    ## Just close the stream/provider, without any error.

  LengthInput*[T] = tuple[length: int64, stream: Input[T]]

let
  JustClose* = (ref CloseException)(msg: "just close")

proc getBufferedInput[T](s: BufferedOutput[T]): BufferedInput[T] {.inline.} = BufferedInput[T](s)

template sself = self.getBufferedInput

proc `$`*[T](input: BufferedInput[T]): string =
  when not defined(release):
    assert input.marker == 0xDEADBEEF'u32
  return "BufferedInput[$1](...)" % name(T)

proc `$`*[T](output: BufferedOutput[T]): string =
  when not defined(release):
    assert output.getBufferedInput.marker == 0xDEADBEEF'u32
  return "BufferedOutput[$1](...)" % name(T)

proc newPipe*[T](input: BufferedInput[T], output: BufferedOutput[T]): Pipe[T] =
  new(result)
  result.input = input
  result.output = output

proc newPipe*[T](t: tuple[input: BufferedInput[T], output: BufferedOutput[T]]): Pipe[T] =
  return newPipe(t.input, t.output)

proc newInputOutputPair*[T](bufferSize=0): tuple[input: BufferedInput[T], output: BufferedOutput[T]] =
  ## Create a new stream/provider pair. Proving values to ``provider`` will make them available on ``stream``.
  ## If more than ``bufferSize`` items are provided without being consumed by stream, ``provide`` operation blocks.
  ## If ``bufferSize == 0`` is the implementation specific default is chosen.
  new(result.input)
  when not defined(release):
    result.input.marker = 0xDEADBEEF'u32
  result.input.queue = newQueue[T](baseBufferSizeFor(T) * 8)

  result.input.bufferSize = if bufferSize == 0: (baseBufferSizeFor(T) * 64) else: bufferSize
  result.output = BufferedOutput[T](result.input)

  newEvent(result.input.onRecvReady)
  newEvent(result.input.onSendReady)

proc newPipe*[T](typ: typedesc[T]): tuple[a: Pipe[T], b: Pipe[T]] =
  result = (Pipe[T](), Pipe[T]())
  (result.a.input, result.b.output) = newInputOutputPair[T]()
  (result.b.input, result.a.output) = newInputOutputPair[T]()

proc increaseBufferSize*[T](self: BufferedOutput[T], size: int) =
  doAssert size >= sself.bufferSize
  sself.bufferSize = size

proc `onRecvReady`*[T](self: BufferedInput[T]): auto =
  self.onRecvReady

proc `onSendReady`*[T](self: BufferedOutput[T]): auto =
  sself.onSendReady

proc getRecvCloseException*(self: BufferedOutput): auto =
  assert sself.recvClosed
  sself.recvCloseException

proc getSendCloseException*(self: BufferedInput): auto =
  assert self.sendClosed
  self.sendCloseException

proc checkProvide(self: BufferedOutput) =
  if sself.sendClosed:
    # This was disabled for some reason. Should we enable this now?
    discard #raise newException(Exception, "provide on closed stream")

proc isRecvClosed*(self: BufferedOutput): bool =
  sself.recvClosed

proc isSendClosed*(self: BufferedInput): bool =
  self.sendClosed

proc sendSome*[T](self: BufferedOutput[T], data: View[T]): int =
  ## Provides some items pointed by view ``data``. Returns how many items
  ## were actualy provided.
  self.checkProvide()
  let doPush = max(min(self.freeBufferSize, data.len), 0)
  if doPush != 0 and sself.queue.len == 0:
    sself.onRecvReady.callListener()

  sself.queue.pushBackMany(data.slice(0, doPush))
  return doPush

proc sendAllSlow[T](self: BufferedOutput[T], data: seq[T]|string|View[T],
                    dataView: View[T], offset: int): Future[void] =
  let completer = newCompleter[void]()
  var offset = offset
  var sendListenerId: CallbackId

  sendListenerId = self.onSendReady.addListener(proc() =
    if sself.sendClosed:
      completer.completeError("send side closed")
      self.onSendReady.removeListener sendListenerId
      return
    if sself.recvClosed:
      completer.completeError(sself.recvCloseException)
      self.onSendReady.removeListener sendListenerId
      return

    offset += self.sendSome(dataView.slice(offset))
    if offset == data.len:
      completer.complete()
      self.onSendReady.removeListener sendListenerId)

  return completer.getFuture

proc sendAll*[T](self: BufferedOutput[T], data: seq[T]|string|View[T]): Future[void] =
  ## Provides items from ``data``. Returns Future that finishes when all
  ## items are provided.
  when type(data) is string and not (T is byte):
    {.error: "writing strings only supported for byte streams".}

  if sself.sendClosed:
    return now(error(void, "send side closed"))

  if sself.recvClosed:
    return now(error(void, sself.recvCloseException))

  var data = data
  let dataView = unsafeInitView(data)

  var offset = self.sendSome(dataView)
  if offset == data.len:
    return now(just())
  else:
    return sendAllSlow(self, data, dataView, offset)

proc maybeSend*[T](self: BufferedOutput[T], item: T): bool =
  return self.sendSome(unsafeInitView(unsafeAddr item, 1)) == 1

proc send*[T](self: BufferedOutput[T], item: T): Future[void] =
  ## Provides a single item. Returns Future that finishes when the item
  ## is pushed into queue.

  self.checkProvide()

  var item = item

  if sself.recvClosed:
    return now(error(void, sself.recvCloseException))

  if self.maybeSend(item):
    return now(just())

  let completer = newCompleter[void]()
  var sendListenerId: CallbackId

  sendListenerId = self.onSendReady.addListener(proc() =
    if sself.recvClosed:
      completer.completeError(sself.recvCloseException)
      self.onSendReady.removeListener sendListenerId
      return

    if self.maybeSend(item):
      completer.complete()
      self.onSendReady.removeListener sendListenerId)

  return completer.getFuture

proc sendClose*(self: BufferedOutput, exc: ref Exception=JustClose) =
  ## Closes the output stream -- signals that no more items will be provided.
  if sself.sendClosed: return
  sself.sendClosed = true
  sself.sendCloseException = exc
  sself.onRecvReady.callListener()

proc waitForRecvClose*[T](self: BufferedOutput[T], callback: proc()) =
  var recvListenerId: CallbackId

  recvListenerId = self.onSendReady.addListener(proc() =
    if sself.recvClosed:
      callback()
      self.onSendReady.removeListener(recvListenerId))

proc recvClose*[T](self: BufferedInput[T], exc: ref Exception=JustClose) =
  ## Closes the input stream -- signals that no more items will be received.
  if self.recvClosed: return
  self.recvClosed = true
  self.recvCloseException = exc
  self.onSendReady.callListener()

proc close*[T](self: Pipe[T], exc: ref Exception=JustClose) =
  self.input.recvClose(exc)
  self.output.sendClose(exc)

proc freeBufferSize*[T](self: BufferedOutput[T]): int =
  ## How many items can be pushed to the queue without blocking?
  return sself.bufferSize - sself.queue.len

proc dataAvailable*[T](self: BufferedInput[T]): int =
  ## How many items can be received from the queue without blocking?
  return self.queue.len

proc peekMany*[T](self: BufferedInput[T]): View[T] =
  ## Look at several items from the input.
  return self.queue.peekFrontMany()

proc discardItems*[T](self: BufferedInput[T], count: int) =
  ## Discard ``count`` items from the stream. Often used after ``peekMany``.
  if BufferedOutput[T](self).freeBufferSize == 0 and count != 0:
    self.onSendReady.callListener()

  self.queue.popFront(count)

proc waitForDataSlow[T](self: BufferedInput[T], allowSpurious=false): Future[void] =
  ## Waits until some data is available in the buffer. For use with ``peekMany`` and ``discardItems``.
  if self.queue.len != 0:
    return now(just())

  if self.sendClosed:
    return now(error(void, self.sendCloseException))

  let completer = newCompleter[void]()
  var recvListenerId: CallbackId

  recvListenerId = self.onRecvReady.addListener(proc() =
    if self.queue.len != 0 or allowSpurious:
      completer.complete()
      self.onRecvReady.removeListener(recvListenerId)
    elif self.sendClosed:
      completer.completeError(self.sendCloseException)
      self.onRecvReady.removeListener(recvListenerId))

  return completer.getFuture

proc waitForData*[T](self: BufferedInput[T], allowSpurious=false): Future[void] =
  if self.queue.len != 0:
    return now(just())

  return self.waitForDataSlow(allowSpurious=allowSpurious)

proc waitForSpace*[T](self: BufferedOutput[T], allowSpurious=false): Future[void] =
  ## Waits until space is available in the buffer. For use with ``sendSome`` and ``freeBufferSize``.
  if self.freeBufferSize != 0:
    return now(just())

  if sself.recvClosed:
    return now(error(void, sself.recvCloseException))

  let completer = newCompleter[void]()
  var sendListenerId: CallbackId

  sendListenerId = self.onSendReady.addListener(proc() =
    if self.freeBufferSize != 0 or allowSpurious:
      completer.complete()
      self.onSendReady.removeListener(sendListenerId)
    elif sself.recvClosed:
      completer.completeError(sself.recvCloseException)
      self.onSendReady.removeListener(sendListenerId))

  return completer.getFuture

proc receiveSomeInto*[T](self: BufferedInput[T], target: View[T]): int =
  ## Pops all available data into ``target``, but not more that the length of ``target``.
  ## Returns the number of bytes copied to target.
  var offset = 0
  while true:
    let view = self.peekMany()
    let doRecv = min(target.len - offset, view.len)
    if doRecv == 0: break
    view.slice(0, doRecv).copyTo(target.slice(offset))
    self.discardItems(doRecv)
    offset += doRecv
  return offset

proc receiveChunkSlow[T, Ret](self: BufferedInput[T], minn: int, maxn: int, returnType: typedesc[Ret]): Future[Ret] =
  var res: Ret = when Ret is seq: newSeq[T](maxn) else: newString(maxn)
  let resView = unsafeInitView(res)

  var offset = self.receiveSomeInto(resView)

  template getResult: untyped =
    if offset == res.len:
      res
    else:
      res[0..<offset]

  if offset >= minn:
    return now(just(getResult()))

  if self.sendClosed:
    return now(error(Ret, self.sendCloseException))

  let completer = newCompleter[Ret]()

  var recvListenerId: CallbackId

  recvListenerId = self.onRecvReady.addListener(proc() =
    offset += self.receiveSomeInto(resView.slice(offset))
    if offset >= minn:
      var res = getResult()
      res.shallow()
      self.onRecvReady.removeListener recvListenerId
      completer.complete(res)
      return
    if self.sendClosed:
      self.onRecvReady.removeListener recvListenerId
      completer.completeError(self.sendCloseException))

  return completer.getFuture

proc receiveChunk[T, Ret](self: BufferedInput[T], minn: int, maxn: int, returnType: typedesc[Ret]): Future[Ret] =
  if self.dataAvailable >= minn:
    let dataLen = min(maxn, self.dataAvailable)
    var res = when Ret is seq: newSeq[T](dataLen) else: newString(dataLen)
    res.shallow
    let offset = self.receiveSomeInto(unsafeInitView(res))
    assert offset == dataLen
    return now(just(res))
  else:
    return self.receiveChunkSlow(minn, maxn, returnType)

proc receiveSome*[T](self: BufferedInput[T], n: int): Future[seq[T]] =
  ## Pops at most ``n`` items from the stream.
  receiveChunk(self, 1, n, seq[T])

proc receiveAll*[T](self: BufferedInput[T], n: int): Future[seq[T]] =
  ## Pops ``n`` items from the stream.
  receiveChunk(self, n, n, seq[T])

proc receive*[T](self: BufferedInput[T]): Future[T] =
  ## Pop an item from the stream.
  return self.receiveAll(1).then((x: seq[T]) => x[0])

proc completeFromStreamClose*(c: Completer[void], err: ref Exception) =
  ## Complete ``c`` with error ``err`` is not ``JustClose``.
  if err.getOriginal == JustClose:
    c.complete()
  else:
    c.completeError(err)

proc pipeChunks*[T, R](self: BufferedInput[T], target: BufferedOutput[R], function: (proc(source: View[T], target: var seq[R]))=nil): Future[void] =
  ## Copy data in chunks from ``self`` to ``target``. If ``function`` is provided it will be called to copy data from source to destination chunks (so custom processing can be made).
  ##
  ## Use this instead of ``pipe`` to reduce function call overhead for small elements.
  ##
  ## Returned future completes successfuly when there is no more data to copy. If any errros occurs the future completes with error.
  var targetListenerId: CallbackId
  var selfListenerId: CallbackId
  let ready = newCompleter[void]()

  proc stop() =
    target.onSendReady.removeListener(targetListenerId)
    self.onRecvReady.removeListener(selfListenerId)

  proc pipeSome() =
    while true:
      let view = self.peekMany()
      if BufferedInput[R](target).recvClosed:
        stop()
        self.recvClose(BufferedInput[R](target).recvCloseException)
        ready.completeFromStreamClose(BufferedInput[R](target).recvCloseException)
        break

      if view.len == 0:
        if self.sendClosed:
          target.sendClose(self.sendCloseException)
          ready.completeFromStreamClose(self.sendCloseException)
          stop()
        break

      if BufferedInput[R](target).sendClosed:
        target.sendClose(newException(ValueError, "write side closed"))
        ready.completeFromStreamClose(newException(ValueError, "write side closed"))
        stop()
        break

      var didSend: int
      if function == nil:
        when T is R:
          didSend = target.sendSome(view)
        else:
          doAssert(false)
      else:
        let doSend = target.freeBufferSize()
        var buffer: seq[R]
        function(view, buffer)
        didSend = target.sendSome(unsafeInitView(addr buffer[0], buffer.len))

      self.discardItems(didSend)
      if didSend == 0: break

  targetListenerId = target.onSendReady.addListener(pipeSome)
  selfListenerId = self.onRecvReady.addListener(pipeSome)
  pipeSome()
  return ready.getFuture

proc mapperFunc[T, R](f: (proc(x: T):R)): auto =
  return proc(source: View[T], target: var seq[R]) =
    target = newSeq[R](source.len)
    for i in 0..<source.len:
      target[i] = f(source[i])

proc flatMapperFunc[T, R](f: (proc(x: T): seq[R])): auto =
  return proc(source: View[T], target: var seq[R]) =
    target = @[]
    for i in 0..<source.len:
      for item in f(source[i]):
        target.add item

proc pipe*[T, R](self: BufferedInput[T], target: BufferedOutput[R], function: (proc(x: T): R)): Future[void] =
  ## Copy data from ``BufferedInput`` to ``BufferedOutput`` while processing them with ``function``.
  ##
  ## Returned future completes successfuly when there is no more data to copy. If any errros occurs the future completes with error.
  # TODO: pipe should return Future[void]
  pipeChunks(self, target, mapperFunc(function))

proc pipe*[T](self: BufferedInput[T], target: BufferedOutput[T]): Future[void] =
  ## Copy data from ``BufferedInput`` to ``BufferedOutput``.
  ##
  ## Returned future completes successfuly when there is no more data to copy. If any errros occurs the future completes with error.
  when not defined(release): assert self.marker == 0xDEADBEEF'u32
  pipeChunks(self, target, nil)

proc mapChunks*[T, R](self: BufferedInput[T], function: (proc(source: View[T], target: var seq[R]))): BufferedInput[R] =
  ## Map data in chunks from ``self`` and return mapped stream. ``function`` will be called to copy data from source to destination chunks (so custom processing can be made).
  ##
  ## Use this instead of ``map`` to function call overhead for small elements.
  let (rstream, rprovider) = newInputOutputPair[R]()
  pipeChunks(self, rprovider, function)
  return rstream

proc flatMap*[T, R](self: BufferedInput[T], function: (proc(x: T): seq[R])): BufferedInput[R] =
  ## Flat-map data from ``self``. Data from ``self`` will be passed to ``function`` and items returned from it will be placed it order in ``result``.
  let (rstream, rprovider) = newInputOutputPair[R]()
  pipeChunks(self, rprovider, flatMapperFunc(function))
  return rstream

proc map*[T, R](self: BufferedInput[T], function: (proc(x: T): R)): BufferedInput[R] =
  ## Map data from ``self`` placing modified data in ``result``.
  let (rstream, rprovider) = newInputOutputPair[R]()
  pipe(self, rprovider, function)
  return rstream

proc map*[T, R](self: BufferedOutput[T], function: (proc(x: R): T)): BufferedOutput[R] =
  ## Map data from ``result`` placing modified data in ``self``.
  let (rstream, rprovider) = newInputOutputPair[R]()
  pipe(rstream, self, function)
  return rprovider

proc unwrapInputFuture*[T](f: Future[BufferedInput[T]]): BufferedInput[T] =
  ## Wait until ``f`` completes and pipe elements from it to ``result``.
  # TODO: implement this without extra copy
  let (input, output) = newInputOutputPair()

  f.onSuccessOrError(proc(newBufferedInput: BufferedInput[T]) = pipe(newBufferedInput, output),
                     proc(exception: ref Exception) = output.sendClose(exception))

  return input

proc unwrapOutputFuture*[T](f: Future[BufferedOutput[T]]): BufferedOutput[T] =
  ## Wait until ``f`` completes and pipe elements from ``result`` to it.
  let (input, output) = newInputOutputPair()

  f.onSuccessOrError(proc(newBufferedOutput: BufferedOutput[T]) = pipe(input, newBufferedOutput),
                     proc(exception: ref Exception) = input.sendClose(exception))

  return output

proc logClose*(err: ref Exception) =
  if not (err.getOriginal of CloseException):
    stderr.writeLine("Closing stream: " & err.msg)

# errorOnClose -> onErrorClose

proc onFinishClose*(f: Future[void], p: BufferedOutput) =
  ## When future f completes, close provider p.
  f.onSuccessOrError(
    onSuccess=proc() = p.sendClose(JustClose),
    onError=proc(t: ref Exception) = p.sendClose(t))

proc onFinishClose*(f: Future[void], s: BufferedInput) =
  ## When future f completes, close stream s.
  f.onSuccessOrError(
    onSuccess=proc() = s.recvClose(JustClose),
    onError=proc(t: ref Exception) = s.recvClose(t))

proc onErrorClose*(f: Future[void], p: BufferedOutput) =
  ## When future f completes with error, close provider p.
  f.onSuccessOrError(
    onSuccess=nothing1[void],
    onError=proc(t: ref Exception) = p.sendClose(t))

proc onErrorClose*(f: Future[void], s: BufferedInput) =
  ## When future f completes with error, close stream s.
  f.onSuccessOrError(
    onSuccess=nothing1[void],
    onError=proc(t: ref Exception) = s.recvClose(t))
