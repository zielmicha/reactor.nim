import reactor/loop, reactor/async, reactor/time
import reactor/http/httpclient

let chunkedUrl = "http://www.httpwatch.com/httpgallery/chunked/chunkedimage.aspx"

proc main() {.async.} =
  let resp0 = await request(newHttpRequest("GET", "http://localhost").get)
  let resp0body = (await resp0.dataStream.readUntilEof())
  echo "finished: ", resp0body

  let conn = await newHttpConnection("127.0.0.1", port=80)
  echo "connected"
  await conn.sendRequest(
    newHttpRequest(httpMethod="GET",
                   path="/", host=nil))
  let resp = await conn.readResponse(expectingBody=true)
  echo resp
  echo(await resp.dataStream.readSome(1000))
  discard await resp.dataStream.readUntilEof()
  echo "ok"

  await conn.sendRequest(
    newHttpRequest(httpMethod="GET",
                   path="/foo", host=nil))

  let resp1 = await conn.readResponse(expectingBody=true)
  echo resp1

when isMainModule:
  main().runMain()
