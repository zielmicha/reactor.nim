import reactor/async, reactor/tcp, reactor/safeuri, reactor/safeuri, strutils, options
import reactor/http/httpcommon

type
  HttpConnection* = ref object
    defaultHost: string
    conn: BytePipe

  HttpError* = object of Exception

const crlf = "\r\L"

proc newHttpConnection*(conn: BytePipe, defaultHost: string): Future[HttpConnection] {.async} =
  return HttpConnection(conn: conn, defaultHost: defaultHost)

proc newHttpConnection*(host: string, port=80): Future[HttpConnection] {.async.} =
  return await newHttpConnection(await connectTcp(host, port), defaultHost=host)

proc newHttpConnection*(req: HttpRequest): Future[HttpConnection] =
  newHttpConnection(req.host, req.port)

proc makeHeaders(request: HttpRequest): Result[string] =
  if not request.httpMethod.hasOnlyChars(Letters + Digits):
    return error(string, "invalid HTTP method")
  if not request.path.hasOnlyChars(AllChars - {'\L', '\r', ' '}):
    return error(string, "invalid HTTP path")

  var header = request.httpMethod & " " & request.path & " HTTP/1.1" & crlf
  for key, value in request.headers.pairs:
    if not key.hasOnlyChars(AllChars - {'\L', '\r', ' '}):
      return error(string, "invalid header key")
    if not value.hasOnlyChars(AllChars - {'\L', '\r'}):
      return error(string, "invalid header value")
    header &= key & ": " & value & crlf
  header &= crlf
  return just(header)

proc sendOnlyRequest*(conn: HttpConnection, request: HttpRequest): Future[void] {.async.} =
  await conn.conn.output.write(await makeHeaders(request))

proc sendRequest*(conn: HttpConnection, request: HttpRequest, closeConnection=false): Future[void] {.async.} =
  if request.data.isSome:
    request.headers["content-length"] = $(request.data.get.length)

  if closeConnection:
    request.headers["connection"] = "close"

  if "host" notin request.headers:
    if request.host != nil:
      request.headers["host"] = request.host
    elif conn.defaultHost != nil:
      request.headers["host"] = conn.defaultHost

  await conn.sendOnlyRequest(request)
  if request.data.isSome:
    await pipeLimited(request.data.get.stream, conn.conn.output, limit=request.data.get.length)

proc readHeaders*(conn: HttpConnection): Future[HttpResponse] {.async.} =
  var headerSizeLimit = 1024 * 8
  let line = await conn.conn.input.readLine(limit=headerSizeLimit)
  if not line.endsWith("\L"): asyncRaise newException(HttpError, "status line too long")

  let statusSplit = line.strip().split(' ')

  if statusSplit.len < 2:
    asyncRaise newException(HttpError, "invalid status line")

  if statusSplit[1].len != 3 or not statusSplit[1].hasOnlyChars(Digits):
    asyncRaise newException(HttpError, "invalid status code")

  let statusCode = statusSplit[1].parseInt

  var headers: HeaderTable = initHeaderTable()

  var lastHeader: string = nil
  var finish = false

  while not finish:
    let line = await conn.conn.input.readLine(limit=headerSizeLimit)
    if not line.endsWith("\L"): asyncRaise newException(HttpError, "header too long")
    finish = (line == "\L" or line == crlf)

    if not finish:
      if line.startsWith(" "): # obs-fold (https://tools.ietf.org/html/rfc7230#section-3.2.4)
        if lastHeader == nil:
          asyncRaise newException(HttpError, "invalid obs-fold")
        lastHeader &= " " & line.strip
        continue

    if lastHeader != nil:
      let colon = lastHeader.find(":")
      if colon == -1:
        asyncRaise newException(HttpError, "malformed header")
      let key = lastHeader[0..<colon]
      let value = lastHeader[colon + 1..^1]
      headers[key] = value
      if headers.len > 200:
        asyncRaise newException(HttpError, "too many headers")

    lastHeader = line.strip(leading=false)

  return HttpResponse(statusCode: statusCode, headers: headers)

proc readWithContentLength*(conn: HttpConnection, length: int64): ByteStream =
  let (stream, provider) = newStreamProviderPair[byte]()
  pipeLimited(conn.conn.input, provider, length).onErrorClose(provider)
  return stream

proc readChunked*(conn: HttpConnection): ByteStream =
  let (stream, provider) = newStreamProviderPair[byte]()

  proc piper() {.async.} =
    while true:
      let info = (await conn.conn.input.readLine(limit=1024)).split(';')[0]
      if not info.endsWith(crlf):
        asyncRaise newException(HttpError, "invalid chunked encoding")

      let length = await tryParseHexUint64(info)
      if length == 0:
        break

      await pipeLimited(conn.conn.input, provider, length)

    provider.sendClose(JustClose)

  piper().onErrorClose(provider)
  return stream

proc readResponse*(conn: HttpConnection, expectingBody=true): Future[HttpResponse] {.async.} =
  let response = await conn.readHeaders()

  if not expectingBody:
    return response

  let te = response.headers.getOrDefault("transfer-encoding", "")
  if te == "chunked":
    response.dataStream = conn.readChunked()
  elif te == "":
    if "content-length" notin response.headers:
      # implicit length
      response.dataStream = conn.conn.input
    else:
      let lengthStr = response.headers["content-length"]
      if lengthStr.len > 19:
        asyncRaise newException(HttpError, "content-length too large")
      let length = await tryParseUint64(lengthStr)

      response.dataStream = conn.readWithContentLength(length)
  else:
    asyncRaise newException(HttpError, "unexpected transfer-encoding")

  return response

proc methodExpectsBody(name: string): bool =
  return name.toUpper != "HEAD"

proc request*(conn: HttpConnection, req: HttpRequest, closeConnection=false): Future[HttpResponse] {.async.} =
  await conn.sendRequest(req, closeConnection)
  return (await conn.readResponse(expectingBody=methodExpectsBody(req.httpMethod)))

proc request*(req: HttpRequest): Future[HttpResponse] {.async.} =
  let conn = await newHttpConnection(req)
  return (await conn.request(req))
