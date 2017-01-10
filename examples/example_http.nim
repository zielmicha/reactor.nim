import reactor/async, reactor/http/httpclient, reactor/http/httpcommon

# async pragma defines an asynchronous method.
# The "real" return type of main is Future[void].
proc main() {.async.} =
  # we use ``await`` to wait for a Future[HttpResponse] to finish
  let resp = await request(newHttpRequest("GET", "http://google.com/").get)
  echo "code: ", resp.statusCode
  # resp.dataInput is of type ByteInput
  let body = resp.dataInput
  # read first 10 bytes of body
  echo (await body.read(10))

when isMainModule:
  # Use runMain to start the event loop
  # Your program will terminate when main() finishes
  main().runMain
