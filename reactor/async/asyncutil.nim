
proc hash*(x: uint64): Hash =
  hash(cast[int64](x))

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
    streamBefore: Stream[SerialQueueItem]
    providerBefore: Provider[SerialQueueItem]
    streamAfter: Stream[proc(): Future[void]]
    providerAfter: Provider[proc(): Future[void]]

proc queueHandlerBefore(q: SerialQueue) {.async.} =
  asyncFor item in q.streamBefore:
    await item.before()
    await q.providerAfter.provide(item.after)

proc queueHandlerAfter(q: SerialQueue) {.async.} =
  asyncFor item in q.streamAfter:
    await item()

proc newSerialQueue*(): SerialQueue =
  let q = new(SerialQueue)
  (q.streamBefore, q.providerBefore) = newStreamProviderPair[SerialQueueItem]()
  (q.streamAfter, q.providerAfter) = newStreamProviderPair[proc(): Future[void]]()
  q.queueHandlerBefore().onErrorClose(q.streamBefore)
  q.queueHandlerAfter().onErrorClose(q.streamAfter)
  return q

proc enqueueInternal(q: SerialQueue, before: (proc(): Future[void]), after: (proc(): Future[void])): Future[void] =
  return q.providerBefore.provide(SerialQueueItem(before: before, after: after))

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

proc forEachChunk*[T](self: Stream[T], function: (proc(x: seq[T]))): Future[void] {.async.} =
  while true:
    let data = await self.receiveSome(4096)
    function(data)

proc forEach*[T](self: Stream[T], function: (proc(x: T))): Future[void] {.async.} =
  asyncFor item in self:
    function(item)

proc pipeLimited*[T](self: Stream[T], provider: Provider[T], limit: int64): Future[void] {.async.} =
  var limit = limit
  while limit > 0:
    let data = await self.receiveSome(max(limit, (baseBufferSizeFor(T) * 8).int64).int)
    limit -= data.len
    await provider.provideAll(data)
  provider.sendClose(JustClose)

proc newConstStream*[T](val: seq[T]): Stream[T] =
  let (stream, provider) = newStreamProviderPair[T]()
  provider.provideAll(val).ignore()
  return stream

proc newConstStream*(val: string): Stream[byte] =
  let (stream, provider) = newStreamProviderPair[byte]()
  provider.provideAll(val).ignore()
  return stream

proc newLengthStream*[T](data: seq[T]): LengthStream[T] =
  (data.len.int64, newConstStream(data))

proc newLengthStream*(data: string): LengthStream[byte] =
  (data.len.int64, newConstStream(data))

proc zip*[A](a: seq[Future[A]]): Future[seq[A]] {.async.} =
  var res: seq[A] = @[]
  for item in a:
    res.add(tryAwait item)
  return res

proc zip*(a: seq[Future[void]]): Future[void] {.async.} =
  for item in a:
    await item
