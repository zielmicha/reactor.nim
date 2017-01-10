# included from reactor/async.nim

type
  BytePipe* = Pipe[byte]
  ByteInput* = Input[byte]
  ByteOutput* = Output[byte]
  LengthByteInput* = LengthInput[byte]

{.deprecated: [ByteStream: ByteInput, ByteProvider: ByteOutput, LengthByteStream: LengthByteInput].}

proc read*(self: Input[byte], count: int): Future[string] =
  ## Reads exactly `count` bytes from stream. Raises error if stream is closed before it manages to read them.
  self.receiveChunk(count, count, string)

proc readSome*(self: Input[byte], maxCount: int): Future[string] =
  ## Reads at least one byte, but not more than `maxCount`. Raises error if stream is closed anything is read.
  self.receiveChunk(1, maxCount, string)

proc readItem*[T](self: Input[byte], `type`: typedesc[T], endian: Endianness): Future[T] =
  ## Read value of type T with specified endanness. (T should be scalar type like int32)
  return self.read(sizeof(T)).then(proc(x: string): T = unpack(x, T, endian))

proc readChunkPrefixed*(self: Input[byte], sizeEndian=bigEndian): Future[string] {.async.} =
  ## Read chunk of text prefixed by 4 byte length
  let length = await self.readItem(uint32, sizeEndian)
  if length > uint32(128 * 1024 * 1024):
    asyncRaise("length too big")
  asyncReturn(await self.read(length.int))

proc readChunksPrefixed*(self: Input[byte], sizeEndian=bigEndian): Input[string] =
  ## Iterate over byte input reading chunks prefixed by length.
  let (input, output) = newInputOutputPair[string]()

  proc pipeChunks() {.async.} =
    while true:
      let chunk = await self.readChunkPrefixed(sizeEndian)
      await output.send(chunk)

  pipeChunks().onSuccessOrError(
    onSuccess=nil,
    onError=proc(err: ref Exception) = output.sendClose(err))

  return input

proc write*(self: Output[byte], data: string): Future[void] =
  ## Alias for Output[byte].sendAll
  return self.sendAll(data)

proc writeItem*[T](self: Output[byte], item: T, endian: Endianness): Future[void] =
  ## Write value of type T with specified endanness. (T should be scalar type like int32)
  return self.write(pack(item, endian))

proc writeChunkPrefixed*(self: Output[byte], item: string, sizeEndian=bigEndian): Future[void] {.async.} =
  ## Write chunk prefixed by 4-byte length.
  await self.writeItem(item.len.uint32, sizeEndian)
  await self.write(item)

proc writeChunksPrefixed*(self: Output[byte]): Output[string] =
  ## Write strings over byte output prefixed by length.
  let (stream, provider) = newInputOutputPair[string]()

  proc pipeChunks() {.async.} =
    while true:
      let item = await stream.receive()
      await self.writeChunkPrefixed(item)

  pipeChunks().onSuccessOrError(
    onSuccess=nil,
    onError=proc(err: ref Exception) = stream.recvClose(err))

  return provider

proc readUntil*(self: Input[byte], chars: set[char], limit=high(int)): Future[string] {.async.} =
  ## Read from stream until one of ``chars`` is read or ``limit`` bytes are read.
  var line = ""
  template addAndTrimToLimit(s: untyped) =
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

proc readUntilEof*(self: Input[byte], limit=high(int)): Future[string] =
  ## Read data until EOF or ``limit`` bytes are read.
  self.readUntil(chars={}, limit=limit)

proc readLine*(self: Input[byte], limit=high(int)): Future[string] =
  ## Read line until LF (0x10) character or ``limit`` bytes are read.
  return self.readUntil(chars={'\L'}, limit=limit)

proc lines*(self: Input[byte], limit=high(int)): Input[string] {.asynciterator.} =
  ## Iterate over lines of an input stream.
  while true:
    asyncYield(await self.readLine(limit=limit))
