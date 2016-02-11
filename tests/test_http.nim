import reactor/loop, reactor/async
import reactor/http/httpclient, reactor/http/httpcommon

let chunkedUrl = "http://www.httpwatch.com/httpgallery/chunked/chunkedimage.aspx"

proc main() {.async.} =
  let resp0 = await request(newHttpRequest("GET", "http://localhost").get)
  echo (await resp0.dataStream.readUntilEof())

  let conn = await newHttpConnection("127.0.0.1", port=80)
  echo "connected"
  await conn.sendRequest(
    newHttpRequest(httpMethod="GET",
                   path="/", host=nil))
  let resp = await conn.readResponse(expectingBody=true)
  echo resp
  echo (await resp.dataStream.readSome(4096 * 4))

  await conn.sendRequest(
    newHttpRequest(httpMethod="GET",
                   path="/foo", host=nil))

  let resp1 = await conn.readResponse(expectingBody=true)
  echo resp1

when isMainModule:
  main().runLoop()
