import reactor, reactor/http, collections

proc main() {.async.} =
  proc cb(req: HttpRequest): Future[HttpResponse] {.async.} =
    echo req
    if req.data.isSome:
      let dataStr = await req.data.get.readUntilEof
      echo "data: ", dataStr
    return newHttpResponse("hello")

  await runHttpServer(port = 8003, callback = cb)

when isMainModule:
  main().runMain
