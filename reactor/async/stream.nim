
type
  Stream*[T] = ref object
    bufferSize: int
    queue: Queue[T]

    onRecvReady: Event[void]
    onSendReady: Event[void]
    sendClosed: bool
    recvClosed: bool
    sendCloseException: ref Exception
    recvCloseException: ref Exception

  Provider* {.borrow: `.`.}[T]  = distinct Stream[T]

  Pipe*[T] = ref object {.inheritable.}
    input*: Stream[T]
    output*: Provider[T]

  CloseException* = object of Exception
    ## Just close the stream/provider, without any error.

  LengthStream*[T] = tuple[length: int64, stream: Stream[T]]

let
  JustClose* = (ref CloseException)(msg: "just close")

proc getStream[T](s: Provider[T]): Stream[T] {.inline.} = Stream[T](s)

template sself = self.getStream

proc newPipe*[T](input: Stream[T], output: Provider[T]): Pipe[T] =
  new(result)
  result.input = input
  result.output = output

proc newStreamProviderPair*[T](bufferSize=0): tuple[stream: Stream[T], provider: Provider[T]] =
  new(result.stream)
  result.stream.queue = newQueue[T]()

  result.stream.bufferSize = if bufferSize == 0: (baseBufferSizeFor(T) * 64) else: bufferSize
  result.provider = Provider[T](result.stream)

  newEvent(result.stream.onRecvReady)
  newEvent(result.stream.onSendReady)

proc `onRecvReady`*[T](self: Stream[T]): auto =
  self.onRecvReady

proc `onSendReady`*[T](self: Provider[T]): auto =
  sself.onSendReady

proc getRecvCloseException*(self: Provider): auto =
  assert sself.recvClosed
  sself.recvCloseException

proc getSendCloseException*(self: Stream): auto =
  assert self.sendClosed
  self.sendCloseException

proc checkProvide(self: Provider) =
  if sself.sendClosed:
    # closes are broken, disable this for now
    discard #raise newException(Exception, "provide on closed stream")

proc isRecvClosed*(self: Provider): bool =
  sself.recvClosed

proc isSendClosed*(self: Stream): bool =
  self.sendClosed

proc provideSome*[T](self: Provider[T], data: ConstView[T]): int =
  ## Provides some items pointed by view `data`. Returns how many items
  ## were actualy provided.
  self.checkProvide()
  let doPush = max(min(self.freeBufferSize, data.len), 0)
  if doPush != 0 and sself.queue.len == 0:
    sself.onRecvReady.callListener()

  sself.queue.pushBackMany(data.slice(0, doPush))
  return doPush

proc provideAll*[T](self: Provider[T], data: seq[T]|string): Future[void] =
  ## Provides items from `data`. Returns Future that finishes when all
  ## items are provided.
  when type(data) is string and not (T is byte):
    {.error: "writing strings only supported for byte streams".}

  if sself.sendClosed:
    return immediateError[void]("send side closed")

  if sself.recvClosed:
    return immediateError[void](sself.recvCloseException)

  when type(data) is string:
    var data = data
    let dataView = asByteView(data)
  else:
    var data = data
    let dataView = seqView(data)

  var offset = self.provideSome(dataView)
  if offset == data.len:
    return immediateFuture()

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

    offset += self.provideSome(dataView.slice(offset))
    if offset == data.len:
      completer.complete()
      self.onSendReady.removeListener sendListenerId)

  return completer.getFuture

proc provide*[T](self: Provider[T], item: T): Future[void] =
  ## Provides a signle. Returns Future that finishes when the item
  ## is pushed into queue.

  self.checkProvide()

  var item = item

  if sself.recvClosed:
    return immediateError[void](sself.recvCloseException)

  if self.provideSome(singleItemView(item)) == 1:
    return immediateFuture()

  let completer = newCompleter[void]()
  var sendListenerId: CallbackId

  sendListenerId = self.onSendReady.addListener(proc() =
    if sself.recvClosed:
      completer.completeError(sself.recvCloseException)
      self.onSendReady.removeListener sendListenerId
      return

    if self.provideSome(singleItemView(item)) == 1:
      completer.complete()
      self.onSendReady.removeListener sendListenerId)

  return completer.getFuture

proc sendClose*(self: Provider, exc: ref Exception) =
  ## Closes the provider -- signals that no more messages will be provided.
  if sself.sendClosed: return
  sself.sendClosed = true
  sself.sendCloseException = exc
  sself.onRecvReady.callListener()

proc recvClose*[T](self: Stream[T], exc: ref Exception) =
  ## Closes the stream -- signals that no more messages will be received.
  if self.recvClosed: return
  self.recvClosed = true
  self.recvCloseException = exc
  self.onSendReady.callListener()

proc close*[T](self: Pipe[T], exc: ref Exception) =
  self.input.recvClose(exc)
  self.output.sendClose(exc)

proc freeBufferSize*[T](self: Provider[T]): int =
  ## How many items can be pushed to the queue?
  return sself.bufferSize - sself.queue.len

proc peekMany*[T](self: Stream[T]): ConstView[T] =
  ## Look at the several items from the streams.
  return self.queue.peekFrontMany()

proc discardItems*[T](self: Stream[T], count: int) =
  ## Discard `count` items from the stream. Often used after `peekMany`.
  if Provider[T](self).freeBufferSize == 0 and count != 0:
    self.onSendReady.callListener()

  self.queue.popFront(count)

proc waitForData*[T](self: Stream[T], allowSpurious=false): Future[void] =
  ## Waits until some data is available in the buffer. For use with `peekMany` and `discardItems`.
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

proc waitForSpace*[T](self: Provider[T], allowSpurious=false): Future[void] =
  ## Waits until space is available in the buffer. For use with `provideSome` and `freeBufferSize`.
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

proc receiveSomeInto*[T](self: Stream[T], target: View[T]): int =
  ## Pops all available data into `target`, but not more that the length of `target`.
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

proc receiveChunk[T, Ret](self: Stream[T], minn: int, maxn: int, returnType: typedesc[Ret]): Future[Ret] =
  var res: Ret = when Ret is seq: newSeq[T](maxn) else: newString(maxn)

  var offset = self.receiveSomeInto(res.asView)

  template getResult: expr =
    if offset == res.len:
      res
    else:
      res[0..<offset]

  if offset >= minn:
    return immediateFuture(getResult())

  if self.sendClosed:
    return immediateError[Ret](self.sendCloseException)

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

proc receiveSome*[T](self: Stream[T], n: int): Future[seq[T]] =
  ## Pops at most `n` items from the stream.
  receiveChunk(self, 1, n, seq[T])

proc receiveAll*[T](self: Stream[T], n: int): Future[seq[T]] =
  ## Pops `n` items from the stream.
  receiveChunk(self, n, n, seq[T])

proc receive*[T](self: Stream[T]): Future[T] =
  ## Pop an item from the stream.
  return self.receiveAll(1).then((x: seq[T]) => x[0])

proc pipeChunks*[T, R](self: Stream[T], target: Provider[R], function: (proc(source: ConstView[T], target: var seq[R]))=nil) =
  var targetListenerId: CallbackId
  var selfListenerId: CallbackId

  proc stop() =
    target.onSendReady.removeListener(targetListenerId)
    self.onRecvReady.removeListener(selfListenerId)

  proc pipeSome() =
    while true:
      let view = self.peekMany()
      if Stream[R](target).recvClosed:
        self.recvClose(Stream[R](target).recvCloseException)
        stop()
        break

      if view.len == 0:
        if self.sendClosed:
          target.sendClose(self.sendCloseException)
          stop()
        break

      if Stream[R](target).sendClosed:
        target.sendClose(newException(ValueError, "write side closed"))
        stop()
        break

      var didSend: int
      if function == nil:
        when T is R:
          didSend = target.provideSome(view)
        else:
          doAssert(false)
      else:
        let doSend = target.freeBufferSize()
        var buffer: seq[R]
        function(view, buffer)
        didSend = target.provideSome(buffer.seqView)

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

proc pipe*[T, R](self: Stream[T], target: Provider[R], function: (proc(x: T): R)) =
  pipeChunks(self, target, mapperFunc(function))

proc pipe*[T](self: Stream[T], target: Provider[T]) =
  pipeChunks(self, target, nil)

proc mapChunks*[T, R](self: Stream[T], function: (proc(source: ConstView[T], target: var seq[R]))): Stream[R] =
  let (rstream, rprovider) = newStreamProviderPair[R]()
  pipeChunks(self, rprovider, function)
  return rstream

proc flatMap*[T, R](self: Stream[T], function: (proc(x: T): seq[R])): Stream[R] =
  let (rstream, rprovider) = newStreamProviderPair[R]()
  pipeChunks(self, rprovider, flatMapperFunc(function))
  return rstream

proc map*[T, R](self: Stream[T], function: (proc(x: T): R)): Stream[R] =
  let (rstream, rprovider) = newStreamProviderPair[R]()
  pipe(self, rprovider, function)
  return rstream

proc map*[T, R](self: Provider[T], function: (proc(x: R): T)): Provider[R] =
  let (rstream, rprovider) = newStreamProviderPair[R]()
  pipe(rstream, self, function)
  return rprovider

proc unwrapStreamFuture[T](f: Future[Stream[T]]): Stream[T] =
  # TODO: implement this without extra copy
  let (stream, provider) = newStreamProviderPair()

  f.onSuccessOrError(proc(newStream: Stream[T]) = pipe(newStream, provider),
                     proc(exception: ref Exception) = provider.sendClose(exception))

  return stream

proc logClose*(err: ref Exception) =
  if not (err.getOriginal of CloseException):
    stderr.writeLine("Closing stream: " & err.msg)

# errorOnClose -> onErrorClose

proc onErrorClose*(f: Future[void], p: Provider) =
  ## When future f completes with error, close provider p.
  f.onSuccessOrError(
    onSuccess=nothing1[void],
    onError=proc(t: ref Exception) = p.sendClose(t))

proc onErrorClose*(f: Future[void], s: Stream) =
  ## When future f completes with error, close stream s.
  f.onSuccessOrError(
    onSuccess=nothing1[void],
    onError=proc(t: ref Exception) = s.recvClose(t))
