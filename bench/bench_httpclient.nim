import reactor/loop, reactor/async
import reactor/http/httpclient, reactor/http/httpcommon

proc request(conn: HttpConnection) {.async.} =
  await conn.sendRequest(newHttpRequest(httpMethod="GET", path="/"))
  let resp = await conn.readResponse(expectingBody=true)
  discard (await resp.dataStream.readSome(4096 * 4))

proc main() {.async.} =
  let conn = await newHttpConnection("127.0.0.1", port=80)

  for i in 1..5000:
    await conn.request
  echo "ok!"

when isMainModule:
  main().runLoop()
