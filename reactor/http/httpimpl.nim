import reactor/async, collections, reactor/http/httpcommon

const crlf* = "\r\L"

proc readChunked*(conn: ByteInput): ByteInput =
  let (input, output) = newInputOutputPair[byte]()

  proc piper() {.async.} =
    while true:
      let line = await conn.readLine(limit=1024)
      let info = line.split(';')[0]
      if not info.endsWith(crlf):
        asyncRaise newException(HttpError, "invalid chunked encoding")

      let length = await tryParseHexUint64(info)
      if length != 0:
        await pipeLimited(conn, output, length, close=false)

      let nl = await conn.read(2)
      if nl != crlf:
        asyncRaise newException(HttpError, "invalid chunked encoding")

      if length == 0:
        break

    output.sendClose(JustClose)

  piper().onErrorClose(output)
  return input

proc toNormalHex(x: int): string =
  const HexChars = "0123456789ABCDEF"

  var x = x
  if x == 0: return "0"

  while x != 0:
    result &= HexChars[x mod 16]
    x = x div 16

  reverse(result)

proc pipeChunked*(src: ByteInput, dst: ByteOutput) {.async.} =
  while true:
    let chunkR = tryAwait src.readSome(1024 * 32)
    if chunkR.isError:
      await dst.write("0\r\n\r\n")
      if chunkR.error.getOriginal == JustClose:
        return
      else:
        discard (await chunkR) # reraise

    await dst.write(toNormalHex(chunkR.get.len) & "\r\n")
    await dst.write(chunkR.get)
    await dst.write("\r\n")

proc readHeaders*(conn: ByteInput): Future[HeaderTable] {.async.} =
  var headerSizeLimit = 1024 * 8

  var headers: HeaderTable = initHeaderTable()

  var lastHeader: Option[string]
  var finish = false

  while not finish:
    let line = await conn.readLine(limit=headerSizeLimit)
    if not line.endsWith("\L"): asyncRaise newException(HttpError, "header too long")
    headerSizeLimit -= line.len
    finish = (line == "\L" or line == crlf)

    if not finish:
      if line.startsWith(" "): # obs-fold (https://tools.ietf.org/html/rfc7230#section-3.2.4)
        if lastHeader.isNone:
          asyncRaise newException(HttpError, "invalid obs-fold")
        lastHeader = some(lastHeader.get & " " & line.strip)
        continue

    if lastHeader.isSome:
      let colon = lastHeader.get.find(":")
      if colon == -1:
        asyncRaise newException(HttpError, "malformed header")
      let key = lastHeader.get[0..<colon]
      let value = lastHeader.get[colon + 1..^1]
      headers[key] = value
      if headers.len > 200:
        asyncRaise newException(HttpError, "too many headers")

    lastHeader = line.strip(leading=false).some

  return headers

proc makeHeaders*(headers: HeaderTable): string =
  for key, value in headers.pairs:
    if not key.hasOnlyChars(AllChars - {'\L', '\r', ' '}):
      raise newException(HttpError, "invalid header key")
    if not value.hasOnlyChars(AllChars - {'\L', '\r'}):
      raise newException(HttpError, "invalid header value")
    result &= key & ": " & value & crlf
  result &= crlf

proc readWithContentLength*(conn: ByteInput, length: int64): ByteInput =
  let (input, output) = newInputOutputPair[byte]()
  pipeLimited(conn, output, length).onErrorClose(output)
  return input

proc isUpgrade*(headers: HeaderTable): bool =
  return "upgrade" in headers.getOrDefault("connection", "").toLowerAscii.split(", ")
