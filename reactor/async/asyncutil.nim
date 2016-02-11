
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
