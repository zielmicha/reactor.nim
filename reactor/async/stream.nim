# included from reactor/async.nim

type
  Input*[T] = ref object
    bufferSize: int
    queue: Queue[T]

    onRecvReady: Event[void]
    onSendReady: Event[void]
    sendClosed: bool
    recvClosed: bool
    sendCloseException: ref Exception
    recvCloseException: ref Exception

  Output* {.borrow: `.`.}[T]  = distinct Input[T]

  Pipe*[T] = ref object {.inheritable.}
    input*: Input[T]
    output*: Output[T]

  CloseException* = object of Exception
    ## Just close the stream/provider, without any error.

  LengthInput*[T] = tuple[length: int64, stream: Input[T]]

{.deprecated: [Stream: Input, Provider: Output, LengthStream: LengthInput].}

let
  JustClose* = (ref CloseException)(msg: "just close")

proc getInput[T](s: Output[T]): Input[T] {.inline.} = Input[T](s)

template sself = self.getInput

proc newPipe*[T](input: Input[T], output: Output[T]): Pipe[T] =
  new(result)
  result.input = input
  result.output = output

proc newInputOutputPair*[T](bufferSize=0): tuple[input: Input[T], output: Output[T]] =
  ## Create a new stream/provider pair. Proving values to ``provider`` will make them available on ``stream``.
  ## If more than ``bufferSize`` items are provided without being consumed by stream, ``provide`` operation blocks.
  ## If ``bufferSize == 0`` is the implementation specific default is chosen.
  new(result.input)
  result.input.queue = newQueue[T](baseBufferSizeFor(T) * 8)

  result.input.bufferSize = if bufferSize == 0: (baseBufferSizeFor(T) * 32) else: bufferSize
  result.output = Output[T](result.input)

  newEvent(result.input.onRecvReady)
  newEvent(result.input.onSendReady)

{.deprecated: [newStreamProviderPair: newInputOutputPair].}

proc `onRecvReady`*[T](self: Input[T]): auto =
  self.onRecvReady

proc `onSendReady`*[T](self: Output[T]): auto =
  sself.onSendReady

proc getRecvCloseException*(self: Output): auto =
  assert sself.recvClosed
  sself.recvCloseException

proc getSendCloseException*(self: Input): auto =
  assert self.sendClosed
  self.sendCloseException

proc checkProvide(self: Output) =
  if sself.sendClosed:
    # closes are broken, disable this for now
    discard #raise newException(Exception, "provide on closed stream")

proc isRecvClosed*(self: Output): bool =
  sself.recvClosed

proc isSendClosed*(self: Input): bool =
  self.sendClosed

proc sendSome*[T](self: Output[T], data: ConstView[T]): int =
  ## Provides some items pointed by view ``data``. Returns how many items
  ## were actualy provided.
  self.checkProvide()
  let doPush = max(min(self.freeBufferSize, data.len), 0)
  if doPush != 0 and sself.queue.len == 0:
    sself.onRecvReady.callListener()

  sself.queue.pushBackMany(data.slice(0, doPush))
  return doPush

proc sendAll*[T](self: Output[T], data: seq[T]|string): Future[void] =
  ## Provides items from ``data``. Returns Future that finishes when all
  ## items are provided.
  when type(data) is string and not (T is byte):
    {.error: "writing strings only supported for byte streams".}

  if sself.sendClosed:
    return now(error(void, "send side closed"))

  if sself.recvClosed:
    return now(error(void, sself.recvCloseException))

  when type(data) is string:
    var data = data
    let dataView = asByteView(data)
  else:
    var data = data
    let dataView = seqView(data)

  var offset = self.sendSome(dataView)
  if offset == data.len:
    return now(just())

  let completer = newCompleter[void]()
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

proc send*[T](self: Output[T], item: T): Future[void] =
  ## Provides a single item. Returns Future that finishes when the item
  ## is pushed into queue.

  self.checkProvide()

  var item = item

  if sself.recvClosed:
    return now(error(void, sself.recvCloseException))

  if self.sendSome(singleItemView(item)) == 1:
    return now(just())

  let completer = newCompleter[void]()
  var sendListenerId: CallbackId

  sendListenerId = self.onSendReady.addListener(proc() =
    if sself.recvClosed:
      completer.completeError(sself.recvCloseException)
      self.onSendReady.removeListener sendListenerId
      return

    if self.sendSome(singleItemView(item)) == 1:
      completer.complete()
      self.onSendReady.removeListener sendListenerId)

  return completer.getFuture

{.deprecated: [provide: send, provideAll: sendAll, provideSome: sendSome].}

proc sendClose*(self: Output, exc: ref Exception) =
  ## Closes the output stream -- signals that no more items will be provided.
  if sself.sendClosed: return
  sself.sendClosed = true
  sself.sendCloseException = exc
  sself.onRecvReady.callListener()

proc recvClose*[T](self: Input[T], exc: ref Exception) =
  ## Closes the input stream -- signals that no more items will be received.
  if self.recvClosed: return
  self.recvClosed = true
  self.recvCloseException = exc
  self.onSendReady.callListener()

proc close*[T](self: Pipe[T], exc: ref Exception) =
  self.input.recvClose(exc)
  self.output.sendClose(exc)

proc freeBufferSize*[T](self: Output[T]): int =
  ## How many items can be pushed to the queue without blocking?
  return sself.bufferSize - sself.queue.len

proc peekMany*[T](self: Input[T]): ConstView[T] =
  ## Look at several items from the input.
  return self.queue.peekFrontMany()

proc discardItems*[T](self: Input[T], count: int) =
  ## Discard ``count`` items from the stream. Often used after ``peekMany``.
  if Output[T](self).freeBufferSize == 0 and count != 0:
    self.onSendReady.callListener()

  self.queue.popFront(count)

proc waitForData*[T](self: Input[T], allowSpurious=false): Future[void] =
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

proc waitForSpace*[T](self: Output[T], allowSpurious=false): Future[void] =
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

proc receiveSomeInto*[T](self: Input[T], target: View[T]): int =
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

proc receiveChunk[T, Ret](self: Input[T], minn: int, maxn: int, returnType: typedesc[Ret]): Future[Ret] =
  var res: Ret = when Ret is seq: newSeq[T](maxn) else: newString(maxn)

  var offset = self.receiveSomeInto(res.asView)

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
    offset += self.receiveSomeInto(res.asView.slice(offset))
    if offset >= minn:
      var res = getResult()
      res.shallow()
      completer.complete(res)
      self.onRecvReady.removeListener recvListenerId
      return
    if self.sendClosed:
      completer.completeError(self.sendCloseException)
      self.onRecvReady.removeListener recvListenerId)

  return completer.getFuture

proc receiveSome*[T](self: Input[T], n: int): Future[seq[T]] =
  ## Pops at most ``n`` items from the stream.
  receiveChunk(self, 1, n, seq[T])

proc receiveAll*[T](self: Input[T], n: int): Future[seq[T]] =
  ## Pops ``n`` items from the stream.
  receiveChunk(self, n, n, seq[T])

proc receive*[T](self: Input[T]): Future[T] =
  ## Pop an item from the stream.
  return self.receiveAll(1).then((x: seq[T]) => x[0])

proc pipeChunks*[T, R](self: Input[T], target: Output[R], function: (proc(source: ConstView[T], target: var seq[R]))=nil) =
  ## Copy data in chunks from ``self`` to ``target``. If ``function`` is provided it will be called to copy data from source to destination chunks (so custom processing can be made).
  ##
  ## Use this instead of ``pipe`` to reduce function call overhead for small elements.
  var targetListenerId: CallbackId
  var selfListenerId: CallbackId

  proc stop() =
    target.onSendReady.removeListener(targetListenerId)
    self.onRecvReady.removeListener(selfListenerId)

  proc pipeSome() =
    while true:
      let view = self.peekMany()
      if Input[R](target).recvClosed:
        self.recvClose(Input[R](target).recvCloseException)
        stop()
        break

      if view.len == 0:
        if self.sendClosed:
          target.sendClose(self.sendCloseException)
          stop()
        break

      if Input[R](target).sendClosed:
        target.sendClose(newException(ValueError, "write side closed"))
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
        didSend = target.sendSome(buffer.seqView)

      self.discardItems(didSend)
      if didSend == 0: break

  targetListenerId = target.onSendReady.addListener(pipeSome)
  selfListenerId = self.onRecvReady.addListener(pipeSome)

proc mapperFunc[T, R](f: (proc(x: T):R)): auto =
  return proc(source: ConstView[T], target: var seq[R]) =
    target = newSeq[R](source.len)
    for i in 0..<source.len:
      target[i] = f(source[i])

proc flatMapperFunc[T, R](f: (proc(x: T): seq[R])): auto =
  return proc(source: ConstView[T], target: var seq[R]) =
    target = @[]
    for i in 0..<source.len:
      for item in f(source[i]):
        target.add item

proc pipe*[T, R](self: Input[T], target: Output[R], function: (proc(x: T): R)) =
  ## Copy data from ``Input`` to ``Output`` while processing them with ``function``.
  # TODO: pipe should return Future[void]
  pipeChunks(self, target, mapperFunc(function))

proc pipe*[T](self: Input[T], target: Output[T]) =
  ## Copy data from ``Input`` to ``Output``.
  pipeChunks(self, target, nil)

proc mapChunks*[T, R](self: Input[T], function: (proc(source: ConstView[T], target: var seq[R]))): Input[R] =
  ## Map data in chunks from ``self`` and return mapped stream. ``function`` will be called to copy data from source to destination chunks (so custom processing can be made).
  ##
  ## Use this instead of ``map`` to function call overhead for small elements.

  let (rstream, rprovider) = newInputOutputPair[R]()
  pipeChunks(self, rprovider, function)
  return rstream

proc flatMap*[T, R](self: Input[T], function: (proc(x: T): seq[R])): Input[R] =
  ## Flat-map data from ``self``. Data from ``self`` will be passed to ``function`` and items returned from it will be placed it order in ``result``.
  let (rstream, rprovider) = newInputOutputPair[R]()
  pipeChunks(self, rprovider, flatMapperFunc(function))
  return rstream

proc map*[T, R](self: Input[T], function: (proc(x: T): R)): Input[R] =
  ## Map data from ``self`` placing modified data in ``result``.
  let (rstream, rprovider) = newInputOutputPair[R]()
  pipe(self, rprovider, function)
  return rstream

proc map*[T, R](self: Output[T], function: (proc(x: R): T)): Output[R] =
  ## Map data from ``result`` placing modified data in ``self``.
  let (rstream, rprovider) = newInputOutputPair[R]()
  pipe(rstream, self, function)
  return rprovider

proc unwrapInputFuture*[T](f: Future[Input[T]]): Input[T] =
  ## Wait until ``f`` completes and pipe elements from it to ``result``.
  # TODO: implement this without extra copy
  let (input, output) = newInputOutputPair()

  f.onSuccessOrError(proc(newInput: Input[T]) = pipe(newInput, output),
                     proc(exception: ref Exception) = output.sendClose(exception))

  return input

proc unwrapOutputFuture*[T](f: Future[Output[T]]): Output[T] =
  ## Wait until ``f`` completes and pipe elements from ``result`` to it.
  let (input, output) = newInputOutputPair()

  f.onSuccessOrError(proc(newOutput: Output[T]) = pipe(input, newOutput),
                     proc(exception: ref Exception) = input.sendClose(exception))

  return output

proc logClose*(err: ref Exception) =
  if not (err.getOriginal of CloseException):
    stderr.writeLine("Closing stream: " & err.msg)

# errorOnClose -> onErrorClose

proc onErrorClose*(f: Future[void], p: Output) =
  ## When future f completes with error, close provider p.
  f.onSuccessOrError(
    onSuccess=nothing1[void],
    onError=proc(t: ref Exception) = p.sendClose(t))

proc onErrorClose*(f: Future[void], s: Input) =
  ## When future f completes with error, close stream s.
  f.onSuccessOrError(
    onSuccess=nothing1[void],
    onError=proc(t: ref Exception) = s.recvClose(t))
