import reactor/util
import reactor/datatypes/queue
import reactor/datatypes/basic
import reactor/async/future
import reactor/loop

type
  Stream*[T] = ref object
    bufferSize: int
    queue: Queue[T]

    onReceiveReadyExec: LoopExecutor
    onSendReadyExec: LoopExecutor
    onReceiveCloseExec: LoopExecutorWithArg[ref Exception]
    onSendCloseExec: LoopExecutorWithArg[ref Exception]

  Provider* {.borrow: `.`.}[T]  = distinct Stream[T]

proc newStreamProviderPair*[T](bufferSize=0): tuple[stream: Stream[T], provider: Provider[T]] =
  new(result.stream)
  result.stream.queue = newQueue[T]()
  if bufferSize == 0:
    bufferSize = baseBufferSizeFor(T) * 64
  result.stream.bufferSize = bufferSize
  result.provider = Provider[T](result.stream)

  result.onReceiveCloseExec = newLoopExecutor()
  result.onSendReadyExec = newLoopExecutor()
  result.onReceiveCloseExec = newLoopExecutorWithArg[ref Exception]()
  result.onSendCloseExec = newLoopExecutorWithArg[ref Exception]()

proc provideSome*[T](self: Provider[T], data: ConstView[T]): int =
  ## Provides some items pointed by view `data`. Returns how many items
  ## were actualy provided.
  let doPush = min(self.freeBufferSize, data.len)
  if doPush != 0 and queue.len == 0:
    self.onReceiveReadyExec.enable()

  self.queue.pushBackMany(data)
  return doPush

proc provideAll*[T](self: Provider[T], data: seq[T]): Future[void] =
  ## Provides items from `data`. Returns Future that finishes when all
  ## items are provided.
  discard

proc provide*[T](self: Provider[T], item: T): Future[void] =
  ## Provides a signle. Returns Future that finishes when the item
  ## is pushed into queue.
  return self.provideMany(@[item])

proc freeBufferSize*[T](self: Provider[T]): int =
  ## How many items can be pushed to the queue?
  return self.bufferSize - self.queue.size

proc peekMany*[T](self: Stream[T]): ConstView[T] =
  ## Look at the several items from the streams.
  return self.queue.peekFrontMany()

proc discardItems*[T](self: Stream[T], count: int) =
  ## Discard `count` items from the stream. Often used after `peekMany`.
  if self.freeBufferSize == 0 and count != 0:
    self.onSendReadyExec.enable()

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

proc pipe*[T, R](self: Stream[T], target: Provider[R], function: (proc(x:T): R)=identity) =
  proc pipeSome() =
    let view = self.peekMany()
    if view.len == 0: return
    var didSend: int
    if function == identity:
      didSend = target.provideSome(view)
    else:
      let doSend = target.freeBufferSize()
      var buffer = newSeq(view.len)
      for i in 0..<view.len:
        buffer[i] = function(view[i])
      didSend = target.provideSome(buffer)
    self.discardItems(didSend)

  let completer = newCompleter()

  self.onSendReady = pipeSome
  target.onRecvReady = pipeSome

  self.onSendClose = proc(info: ref Exception) =
    target.closeRecv(info)

  target.onRecvClose = proc(info: ref Exception) =
    self.closeRecv(info)

proc pipe*[T](self: Stream[T], target: Provider[T]) =
  pipe(self, target, identity)

proc map*[T, R](self: Stream[T], function: (proc(x: T): R)): Stream[R] =
  let (rstream, rprovider) = newStreamProviderPair[R]()
  pipe(self, rprovider, function)
  return rstream
