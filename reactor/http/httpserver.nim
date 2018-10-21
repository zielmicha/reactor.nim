import reactor/async, reactor/tcp, reactor/ipaddress, strutils, options, strformat
import reactor/http/httpcommon, reactor/http/httpimpl

proc writeHeaders*(conn: ByteOutput, response: HttpResponse): Future[void] {.async.} =
  await conn.write("HTTP/1.1 " & $response.statusCode & " -" & crlf)
  await conn.write(makeHeaders(response.headers))

proc writeResponse*(conn: ByteOutput, response: HttpResponse): Future[void] {.async.} =
  response.headers["transfer-encoding"] = "chunked"
  await conn.writeHeaders(response)
  await pipeChunked(response.dataInput, conn)

proc readRequestHeaders*(conn: ByteInput): Future[HttpRequest] {.async.} =
  let line = await conn.readLine(limit=1024 * 8)
  if not line.endsWith("\L"):
    raise newException(HttpError, "request line too long")

  let spl = line.strip().split(" ")
  if spl.len != 3:
    raise newException(HttpError, "invalid request line")

  if spl[2] notin @["HTTP/1.0", "HTTP/1.1"]:
    raise newException(HttpError, "invalid HTTP version")

  let headers = await readHeaders(conn)

  return HttpRequest(
    httpMethod: spl[0],
    path: spl[1],
    headers: headers
  )

proc readRequest*(conn: ByteInput): Future[HttpRequest] {.async.} =
  let req = await readRequestHeaders(conn)

  # https://stackoverflow.com/questions/16339198/which-http-methods-require-a-body
  let te = req.headers.getOrDefault("transfer-encoding", "")
  if te == "chunked":
    req.data = some(conn.readChunked())
  elif "content-length" in req.headers:
    if req.headers["content-length"].len > 19:
      raise newException(HttpError, "content-length too large")

    let length = tryParseUint64(req.headers["content-length"]).get
    req.data = some(conn.readWithContentLength(length))
    req.dataLength = some(length)

  return req

proc runHttpServer*(conn: BytePipe, callback: proc(req: HttpRequest): Future[HttpResponse]) {.async.} =
  defer: conn.close

  while true:
    let reqR = tryAwait conn.input.readRequest()
    if reqR.isError:
      break

    let req = reqR.get
    let resp = await callback(req)
    await conn.output.writeResponse(resp)

    # make sure request body is read fully
    if req.data.isSome:
      let e = (tryAwait req.data.get.readUntilEof())
      if e.isError: break

proc runHttpServer*(port: int, addresses: seq[IpAddress]=localhostAddresses, callback: proc(req: HttpRequest): Future[HttpResponse]) {.async.} =
  let server = await createTcpServer(port, addresses)
  await server.incomingConnections.forEach(
    proc(conn: TcpConnection) =
      runHttpServer(conn, callback).ignore
  )
