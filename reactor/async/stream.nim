
type
  Stream*[T] = ref object
    bufferSize: int
    queue: Queue[T]

    onRecvReady: Event[void]
    onSendReady: Event[void]
    onRecvClose: Event[ref Exception]
    onSendClose: Event[ref Exception]
    sendClosed: bool
    recvClosed: bool

  Provider* {.borrow: `.`.}[T]  = distinct Stream[T]

  Pipe*[T] = ref object {.inheritable.}
    input*: Stream[T]
    output*: Provider[T]

  CloseException* = Exception
    ## Just close the stream/provider, without any error.

proc getStream[T](s: Provider[T]): Stream[T] {.inline.} = Stream[T](s)

template sself = self.getStream

proc newStreamProviderPair*[T](bufferSize=0): tuple[stream: Stream[T], provider: Provider[T]] =
  new(result.stream)
  result.stream.queue = newQueue[T]()

  result.stream.bufferSize = if bufferSize == 0: (baseBufferSizeFor(T) * 64) else: bufferSize
  result.provider = Provider[T](result.stream)

  newEvent(result.stream.onRecvReady)
  newEvent(result.stream.onSendReady)
  newEvent(result.stream.onRecvClose)
  newEvent(result.stream.onSendClose)

proc `onSendClose`*[T](self: Stream[T]): auto =
  self.onSendClose

proc `onRecvClose`*[T](self: Provider[T]): auto =
  sself.onSendClose

proc `onRecvReady`*[T](self: Stream[T]): auto =
  self.onRecvReady

proc `onSendReady`*[T](self: Provider[T]): auto =
  sself.onSendReady

proc checkProvide(self: Provider) =
  if sself.sendClosed:
    raise newException(Exception, "provide on closed stream")

proc provideSome*[T](self: Provider[T], data: ConstView[T]): int =
  ## Provides some items pointed by view `data`. Returns how many items
  ## were actualy provided.
  self.checkProvide()
  let doPush = min(self.freeBufferSize, data.len)
  if doPush != 0 and sself.queue.len == 0:
    sself.onRecvReady.callListener()

  sself.queue.pushBackMany(data)
  return doPush

proc provideAll*[T](self: Provider[T], data: seq[T]): Future[void] =
  ## Provides items from `data`. Returns Future that finishes when all
  ## items are provided.
  raise newException(Exception, "not implemented")

proc provide*[T](self: Provider[T], item: T): Future[void] =
  ## Provides a signle. Returns Future that finishes when the item
  ## is pushed into queue.
  return self.provideMany(@[item])

proc sendClose*(self: Provider, exc: ref Exception) =
  ## Closes the provider -- signals that no more messages will be provided.
  if sself.sendClosed: return
  sself.sendClosed = true
  sself.onSendClose.callListener(exc)

proc recvClose*[T](self: Stream[T], exc: ref Exception) =
  ## Closes the stream -- signals that no more messages will be received.
  if self.recvClosed: return
  self.recvClosed = true
  self.onRecvReady.removeAllListeners
  self.onRecvClose.callListener(exc)

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

proc receive*[T](self: Stream[T]): Future[T] =
  ## Pop an item from the stream.
  return self.receiveMany(1).then(x => x[0])

proc receiveMany*[T](self: Stream[T], limit=64 * 1024): Future[seq[T]] =
  ## Pop unspecified number of items from the stream.
  if self.queue.len != 0:
    let view = self.peekMany()
    let doPop = min(limit, view.len)
    let r = view.slice(0, doPop).copyAsSeq()
    r.shallow()
    self.discardItems(doPop)
    return immediateFuture(r)

  let completer = newCompleter()

  self.onSendReady = proc() =
    completer.completeFrom(self.receiveMany(limit=limit))
    self.onSendReady = nil

  self.onSendClose = proc() =
    completer.completeError("stream closed")

  return completer.getFuture

proc receiveAll*[T](self: Stream[T], n: int): Future[seq[T]] =
  ## Pop `n` items from the stream.

  var res: seq[T] = @[]
  let completer = newCompleter()

  static: assert 0, "unimplemented"

  return completer.getFuture

proc forEachChunk*[T](self: Stream[T], function: (proc(x: ConstView[T]): Future[int])): Future[Bottom] =
  ## Read the stream and execute `function` for every incoming sequence of items. The function should return the number of items that were consumed.
  let completer = newCompleter[Bottom]()

  var onRecvContinue: (proc(n: int))
  var recvListenerId: CallbackId

  var onRecvReady = proc() =
    while true: # FIXME: potentially infinite
      let chunk = self.peekMany()
      if chunk.len == 0:
        break
      let nitems = function(chunk)
      if nitems.isCompleted:
        self.discardItems(nitems.get)
      else:
        self.onRecvReady.removeListener(recvListenerId)
        nitems.onSuccessOrError(
          onSuccess=onRecvContinue,
          onError=proc(exc: ref Exception) = self.recvClose(exc))
        break

  onRecvContinue = proc(n: int) =
    self.discardItems(n)
    recvListenerId = self.onRecvReady.addListener(onRecvReady)
    onRecvReady()

  recvListenerId = self.onRecvReady.addListener(onRecvReady)

  self.onSendClose.addListener proc(exc: ref Exception) =
    completer.completeError(exc)

  let f: Future[Bottom] = completer.getFuture
  return f

proc forEachChunk*[T](self: Stream[T], function: (proc(x: ConstView[T]))): Future[Bottom] =
  self.forEachChunk proc(x: ConstView[T]): Future[int] =
    function(x)
    return immediateFuture(x.len)

proc forEachChunk*[T](self: Stream[T], function: (proc(x: seq[T]))): Future[Bottom] =
  self.forEachChunk proc(x: ConstView[T]) =
    function(x.copyAsSeq)

proc forEach*[T](self: Stream[T], function: (proc(x: T))): Future[Bottom] =
  self.forEachChunk proc(x: ConstView[T]) =
    for i in 0..<x.len:
      function(x[i])

proc pipeChunks*[T, R](self: Stream[T], target: Provider[R], function: (proc(source: ConstView[T], target: var seq[R]))=identity) =
  proc pipeSome() =
    let view = self.peekMany()
    if view.len == 0: return
    var didSend: int
    if function == identity:
      didSend = target.provideSome(view)
    else:
      let doSend = target.freeBufferSize()
      var buffer = newSeq(view.len)
      function(view, buffer)
      didSend = target.provideSome(buffer)
    self.discardItems(didSend)

  let completer = newCompleter()

  self.onSendReady = pipeSome
  target.onRecvReady = pipeSome

  self.onSendClose = proc(info: ref Exception) =
    target.closeRecv(info)

  target.onRecvClose = proc(info: ref Exception) =
    self.closeRecv(info)

proc mapperFunc[T, R](f: (proc(x: T):R)): auto =
  return proc(source: ConstView[T], target: var seq[R]) =
    for i in 0..<source.len:
      target[i] = f(source[i])

proc pipe*[T, R](self: Stream[T], target: Provider[R], function: (proc(x: T): R)) =
  pipe(self, target, mapperFunc(function))

proc pipe*[T](self: Stream[T], target: Provider[T]) =
  pipeChunks(self, target, identity)

proc mapChunks*[T, R](self: Stream[T], function: (proc(source: ConstView[T], target: var seq[R]))): Stream[R] =
  let (rstream, rprovider) = newStreamProviderPair[R]()
  pipeChunks(self, rprovider, function)
  return rstream

proc map*[T, R](self: Stream[T], function: (proc(x: T): R)): Stream[R] =
  let (rstream, rprovider) = newStreamProviderPair[R]()
  pipe(self, rprovider, function)
  return rstream

proc unwrapStreamFuture[T](f: Future[Stream[T]]): Stream[T] =
  # TODO: implement this without extra copy
  let (stream, provider) = newStreamProviderPair()

  f.onSuccessOrError(proc(newStream: Stream[T]) = pipe(newStream, provider),
                     proc(exception: ref Exception) = provider.sendClose(exception))

  return stream
