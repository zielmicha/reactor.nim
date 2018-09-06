# included from reactor/async.nim

type
  AsyncMutex* = ref object
    locked: bool
    wakeQueue: Queue[Completer[void]]

proc newAsyncMutex*(): AsyncMutex =
  return AsyncMutex(locked: false, wakeQueue: newQueue[Completer[void]](chunkSize=8))

proc lock*(mutex: AsyncMutex): Future[void] =
  if mutex.locked:
    let c = newCompleter[void]()
    mutex.wakeQueue.pushBack(c)
    return c.getFuture
  else:
    mutex.locked = true
    return now(just())

proc unlock*(mutex: AsyncMutex) =
  doAssert mutex.locked

  if mutex.wakeQueue.len == 0:
    mutex.locked = false
  else:
    let completer = mutex.wakeQueue.peekFrontMany()[0]
    mutex.wakeQueue.popFront()
    completer.complete()
