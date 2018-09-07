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
