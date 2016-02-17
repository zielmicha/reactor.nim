type
  BytePipe* = Pipe[byte]
  ByteStream* = Stream[byte]
  ByteProvider* = Provider[byte]
  LengthByteStream* = LengthStream[byte]

proc read*(self: Stream[byte], count: int): Future[string] =
  ## Reads exactly `count` bytes from stream. Raises error if stream is closed before it manages to read them.
  self.receiveChunk(count, count, string)

proc readSome*(self: Stream[byte], maxCount: int): Future[string] =
  ## Reads at least one byte, but not more than `maxCount`. Raises error if stream is closed anything is read.
  self.receiveChunk(1, maxCount, string)

proc readItem*[T](self: Stream[byte], `type`: typedesc[T], endian=bigEndian): Future[T] =
  return self.read(sizeof(T)).then(proc(x: string): T = unpack(x, T, endian))

proc readChunkPrefixed*(self: Stream[byte]): Future[string] {.async.} =
  let length = await self.readItem(uint32)
  if length > uint32(128 * 1024 * 1024):
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
  return self.provideAll(data)

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

proc readUntil*(self: Stream[byte], chars: set[char], limit=high(int)): Future[string] {.async.} =
  var line = ""
  template addAndTrimToLimit(s: expr) =
    assert line.len <= limit
    var value = s
    if value.len > limit - line.len:
      value.setLen(limit - line.len)
    line &= value
    self.discardItems(value.len)

  block main:
    while true:
      var view = self.peekMany()

      for i in 0..<view.len:
        if view[i].char in chars:
          addAndTrimToLimit(view.slice(0, i + 1).copyAsString)
          break main

      addAndTrimToLimit(view.copyAsString)
      if line.len == limit:
        break

      if view.len == 0:
        let status = (tryAwait self.waitForData)
        if status.isError:
          if line.len == 0:
            asyncRaise status.error
          else:
            break

  return line

proc readUntilEof*(self: Stream[byte], limit=high(int)): Future[string] =
  self.readUntil(chars={}, limit=limit)

proc readLine*(self: Stream[byte], limit=high(int)): Future[string] =
  return self.readUntil(chars={'\L'}, limit=limit)

proc lines*(self: Stream[byte], limit=high(int)): Stream[string] {.asynciterator.} =
  while true:
    asyncYield (await self.readLine(limit=limit))
