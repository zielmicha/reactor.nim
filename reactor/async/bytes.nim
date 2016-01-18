type
  BytePipe* = Pipe[byte]
  ByteStream* = Stream[byte]
  ByteProvider* = Provider[byte]

proc forEachChunk*(self: Stream[byte], function: (proc(x: string))): Future[Bottom] =
  self.forEachChunk proc(x: ConstView[byte]) =
    function(x.copyAsString)

proc forEachChunk*(self: Stream[byte], function: (proc(x: string): Future[void])): Future[Bottom] =
  self.forEachChunk proc(x: ConstView[byte]): Future[int] =
    function(x.copyAsString).then(proc(): int = x.len)

proc read*(self: Stream[byte], count: int): Future[string] =
  self.receiveAll(count, string)

proc readItem*[T](self: Stream[byte], `type`: typedesc[T], endian=bigEndian): Future[T] =
  return self.read(sizeof(T)).then(proc(x: string): T = unpack(x, T, endian))

proc readChunkPrefixed*(self: Stream[byte]): Future[string] {.async.} =
  let length = await self.readItem(uint32)
  if length > uint32(16 * 1024 * 1024):
    asyncRaise("length too big")
  asyncReturn(await self.read(length.int))

proc readChunksPrefixed*(self: Stream[byte]): Stream[string] =
  let (stream, provider) = newStreamProviderPair[string]()

  proc pipeChunks() {.async.} =
    while true:
      let chunk = await self.readChunkPrefixed()
      await provider.provide(chunk)

  pipeChunks().onSuccessOrError(
    onSuccess=nil,
    onError=proc(err: ref Exception) = provider.sendClose(err))

  return stream

proc write*[T](self: Provider[T], data: string): Future[void] =
  self.provideAll(data)

proc writeItem*[T](self: Provider[byte], item: T, endian=bigEndian): Future[void] =
  return self.write(pack(item, endian))

proc writeChunkPrefixed*(self: Provider[byte], item: string): Future[void] {.async.} =
  await self.writeItem(item.len.uint32)
  await self.write(item)

proc writeChunksPrefixed*(self: Provider[byte]): Provider[string] =
  let (stream, provider) = newStreamProviderPair[string]()

  proc pipeChunks() {.async.} =
    while true:
      let item = await stream.receive()
      await self.writeChunkPrefixed(item)

  pipeChunks().onSuccessOrError(
    onSuccess=nil,
    onError=proc(err: ref Exception) = stream.recvClose(err))

  return provider
