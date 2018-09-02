# included from reactor/async.nim

type CompleterTable*[K, V] = ref object
  ## A dictionary of completers. Useful for implementing RPC protocols with message ids.
  completers: Table[K, seq[Completer[V]]]

proc newCompleterTable*[K, V](): CompleterTable[K, V] =
  ## Creates a dictionary of completers.
  new(result)
  result.completers = initTable[K, seq[Completer[V]]]()

proc waitFor*[K, V](self: CompleterTable[K, V], id: K): Future[V] =
  ## Wait for completion of event with id `id`. Doesn't return values for already completed events.
  let completer = newCompleter[V]()
  self.completers.mgetOrPut(id, newSeq[Completer[V]]()).add completer
  completer.getFuture

proc complete*[K, V](self: CompleterTable[K, V], id: K, value: V) =
  ## Complete all futures requested by `waitFor` for id `id`.
  let v = self.completers.getOrDefault(id)
  if v != nil:
    for completer in v:
      completer.complete(value)
    self.completers.del(id)

# serial queue

type
  SerialQueueItem = ref object # FIXME: object without ref causes problems with sizeof
    before: (proc(): Future[void])
    after: (proc(): Future[void])

  SerialQueue* = ref object
    ## A queue that executes asynchronous functions serially
    streamBefore: Input[SerialQueueItem]
    providerBefore: Output[SerialQueueItem]
    streamAfter: Input[proc(): Future[void]]
    providerAfter: Output[proc(): Future[void]]

proc queueHandlerBefore(q: SerialQueue) {.async.} =
  asyncFor item in q.streamBefore:
    await item.before()
    await q.providerAfter.send(item.after)

proc queueHandlerAfter(q: SerialQueue) {.async.} =
  asyncFor item in q.streamAfter:
    await item()

proc newSerialQueue*(): SerialQueue =
  let q = new(SerialQueue)
  (q.streamBefore, q.providerBefore) = newInputOutputPair[SerialQueueItem]()
  (q.streamAfter, q.providerAfter) = newInputOutputPair[proc(): Future[void]]()
  q.queueHandlerBefore().onErrorClose(q.streamBefore)
  q.queueHandlerAfter().onErrorClose(q.streamAfter)
  return q

proc enqueueInternal(q: SerialQueue, before: (proc(): Future[void]), after: (proc(): Future[void])): Future[void] =
  return q.providerBefore.send(SerialQueueItem(before: before, after: after))

proc enqueue*[T](q: SerialQueue, before: (proc(): Future[void]), after: (proc(): Future[T])): Future[T] {.async.} =
  ## Executes all `before`s and `after`s in the same order. Additionally, if `enqueue` A is executed before `enqueue` B
  ## functions from A will be executed before functions from `B`.
  let completer = newCompleter[T]()

  proc afterProc(): Future[void] =
    let queueCompleter = newCompleter[void]()
    after().onSuccessOrError(
      onSuccess=(proc(x: T) =
                   when T is void:
                     completer.complete()
                   else:
                     completer.complete(x)
                   queueCompleter.complete()),
      onError=(proc(err: ref Exception) =
                 completer.completeError(err)
                 queueCompleter.completeError(err)))

    return queueCompleter.getFuture

  await q.enqueueInternal(before, afterProc)

  when T is void:
    await completer.getFuture
  else:
    return (await completer.getFuture)

# forEach

proc forEachChunk*[T](self: Input[T], function: (proc(x: seq[T]))): Future[void] {.async.} =
  while true:
    let data = await self.receiveSome(4096)
    function(data)

proc forEach*[T](self: Input[T], function: (proc(x: T))): Future[void] {.async.} =
  asyncFor item in self:
    function(item)

proc pipeLimited*[T](self: Input[T], provider: Output[T], limit: int64, close=true): Future[void] {.async.} =
  # FIXME: close on error?
  var limit = limit
  while limit > 0:
    let res = tryAwait self.receiveSome(min(limit, (baseBufferSizeFor(T) * 8).int64).int)
    if not res.isSuccess and res.error.getOriginal of CloseException:
      break # TODO: is this right?
    let data = await res
    limit -= data.len
    assert limit >= 0
    await provider.sendAll(data)

  if close:
    provider.sendClose(JustClose)

proc newConstInput*[T](val: seq[T]): Input[T] =
  let (stream, provider) = newInputOutputPair[T]()
  provider.sendAll(val).ignore()
  return stream

proc newConstInput*(val: string): Input[byte] =
  let (stream, provider) = newInputOutputPair[byte]()
  provider.sendAll(val).ignore()
  return stream

proc newLengthInput*[T](data: seq[T]): LengthInput[T] =
  (data.len.int64, newConstInput(data))

proc newLengthInput*(data: string): LengthInput[byte] =
  (data.len.int64, newConstInput(data))

proc nullOutput*[T](t: typedesc[T]): Output[T] =
  let (input, output) = newInputOutputPair[byte]()
  input.forEachChunk(proc(x: seq[T]) = discard).onErrorClose(input)
  return output

proc zip*[A](a: seq[Future[A]]): Future[seq[A]] {.async.} =
  var res: seq[A] = @[]
  for item in a:
    res.add(tryAwait item)
  return res

proc zipVoid*(a: seq[Future[void]]): Future[void] =
  let completer = newCompleter[void]()
  var waiting = a.len
  for f in a:
    f.onSuccessOrError(
      (proc() =
        waiting -= 1
        if waiting == 0:
          completer.complete()),
      (proc(err: ref Exception) =
        if not completer.getFuture.isCompleted:
          completer.completeError(err)))

  return completer.getFuture

proc anyFuture*[T](futures: seq[Future[T]]): Future[T] =
  ## Wait until one of the futures finishes successfully.
  ## If all of the futures fail, return an error.
  var futures = futures
  let completer = newCompleter[void]()
  var remaining = futures.len

  proc callback(num: int): proc() =
    return proc(r: Result[T]) =
             if not completer.getFuture.isCompleted:
               if r.isError:
                 remaining -= 1
                 if remaining == 0:
                   completer.complete(r)
               else:
                 completer.complete(r)

               for i, fut in futures:
                 if i != num:
                   fut.ignore
               futures = nil # GC

  for i, fut in futures:
    fut.onSuccessOrError(callback(i))

  return completer.getFuture

proc splitFuture*[A, B](f: Future[tuple[a: A, b: B]]): tuple[a: Future[A], b: Future[B]] =
  ## Converts a future of tuple to tuple of futures.
  let ca = newCompleter[A]()
  let cb = newCompleter[B]()
  f.onSuccessOrError((proc(v: (A, B)) =
                         ca.complete(v.a)
                         ca.complete(v.b)),
                     (proc(exception: ref Exception) =
                         ca.completeError(exception)
                         cb.completeError(exception)))

  return (ca.getFuture, cb.getFuture)

proc unwrapPipeFuture*[T](f: Future[Pipe[T]]): Pipe[T] =
  let fs = f.map(p => (p.stream, p.provider)).splitFuture
  return (unwrapInputFuture(fs[0]), unwrapOutputFuture(fs[1]))

proc pipe*[T](a: Pipe[T], b: Pipe[T]): Future[void] =
  let f1 = pipe(a.input, b.output)
  let f2 = pipe(b.input, a.output)
  return zipVoid(@[f1, f2])

proc asyncPipe*[T](f: proc(s: Input[T]): Future[void]): Output[T] =
  ## Create a new pipe, return output side. Call `f` in background with input as an argument
  ## - when it errors, close the output.
  let (input, output) = newInputOutputPair[T]()
  f(input).onErrorClose(input)
  return output
