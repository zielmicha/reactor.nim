import reactor/async, reactor/tcp, strutils, options
import reactor/http/httpcommon, reactor/http/httpimpl
export httpcommon, httpimpl

type
  HttpConnection* = ref object
    defaultHost: string
    conn: BytePipe

proc newHttpConnection*(conn: BytePipe, defaultHost: string): Future[HttpConnection] {.async} =
  return HttpConnection(conn: conn, defaultHost: defaultHost)

proc newHttpConnection*(host: string, port=80): Future[HttpConnection] {.async.} =
  let conn = await connectTcp(host, port)
  return newHttpConnection(conn, defaultHost=host)

proc newHttpConnection*(req: HttpRequest): Future[HttpConnection] =
  newHttpConnection(req.host, req.port)

proc makeHeaders(request: HttpRequest): Result[string] =
  if not request.httpMethod.hasOnlyChars(Letters + Digits):
    return error(string, "invalid HTTP method")
  if not request.path.hasOnlyChars(AllChars - {'\L', '\r', ' '}):
    return error(string, "invalid HTTP path")

  let path = if request.path == "": "/" else: request.path
  var header = request.httpMethod & " " & path & " HTTP/1.1" & crlf
  for key, value in request.headers.pairs:
    if not key.hasOnlyChars(AllChars - {'\L', '\r', ' '}):
      return error(string, "invalid header key")
    if not value.hasOnlyChars(AllChars - {'\L', '\r'}):
      return error(string, "invalid header value")
    header &= key & ": " & value & crlf
  header &= crlf
  return just(header)

proc sendOnlyRequest*(conn: HttpConnection, request: HttpRequest): Future[void] {.async.} =
  await conn.conn.output.write(makeHeaders(request).get)

proc sendRequest*(conn: HttpConnection, request: HttpRequest, closeConnection=false): Future[void] {.async.} =
  if request.data.isSome:
    request.headers["content-length"] = $(request.data.get.length)

  if closeConnection:
    request.headers["connection"] = "close"

  if "host" notin request.headers:
    if request.host != "":
      request.headers["host"] = request.host
    elif conn.defaultHost != "":
      request.headers["host"] = conn.defaultHost

  await conn.sendOnlyRequest(request)
  if request.data.isSome:
    await pipeLimited(request.data.get.stream, conn.conn.output, limit=request.data.get.length)

proc readHeaders*(conn: HttpConnection): Future[HttpResponse] {.async.} =
  var headerSizeLimit = 1024 * 8
  let line = await conn.conn.input.readLine(limit=headerSizeLimit)
  if not line.endsWith("\L"): raise newException(HttpError, "status line too long")

  let statusSplit = line.strip().split(' ')

  if statusSplit.len < 2:
    asyncRaise newException(HttpError, "invalid status line")

  if statusSplit[1].len != 3 or not statusSplit[1].hasOnlyChars(Digits):
    asyncRaise newException(HttpError, "invalid status code")

  let statusCode = statusSplit[1].parseInt
  let headers = await readHeaders(conn.conn.input)

  return HttpResponse(statusCode: statusCode, headers: headers)

proc readWithContentLength*(conn: HttpConnection, length: int64): ByteInput =
  let (input, output) = newInputOutputPair[byte]()
  pipeLimited(conn.conn.input, output, length).onErrorClose(output)
  return input

proc readResponse*(conn: HttpConnection, expectingBody=true): Future[HttpResponse] {.async.} =
  let response = await conn.readHeaders()

  if not expectingBody:
    return response

  let te = response.headers.getOrDefault("transfer-encoding", "")
  if te == "chunked":
    response.dataInput = conn.conn.input.readChunked()
  elif te == "":
    if "content-length" notin response.headers:
      # implicit length
      response.dataInput = conn.conn.input
    else:
      let lengthStr = response.headers["content-length"]
      if lengthStr.len > 19:
        asyncRaise newException(HttpError, "content-length too large")
      let length = await tryParseUint64(lengthStr)

      response.dataInput = conn.readWithContentLength(length)
  else:
    asyncRaise newException(HttpError, "unexpected transfer-encoding")

  return response

proc methodExpectsBody(name: string): bool =
  return name.toUpperAscii != "HEAD"

proc request*(conn: HttpConnection, req: HttpRequest, closeConnection=false): Future[HttpResponse] {.async.} =
  await conn.sendRequest(req, closeConnection)
  return conn.readResponse(expectingBody=methodExpectsBody(req.httpMethod))

proc request*(req: HttpRequest): Future[HttpResponse] {.async.} =
  let conn = await newHttpConnection(req)
  return conn.request(req)
