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

proc write*[T](self: Provider[T], data: string): Future[void] =
  self.provideAll(data)

proc writeItem*[T](self: Provider[byte], item: T, endian=bigEndian): Future[void] =
  return self.write(pack(item, endian))
