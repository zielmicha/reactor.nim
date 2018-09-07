import reactor, reactor/http

proc main() {.async.} =
  proc cb(req: HttpRequest): Future[HttpResponse] {.async.} =
    return newHttpResponse("hello")

  await runHttpServer(port = 8003, callback = cb)

when isMainModule:
  main().runMain
