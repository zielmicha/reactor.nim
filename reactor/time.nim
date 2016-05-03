include reactor/uv/uvtime

proc repeatUntilSuccess*[T](f: (proc(): Future[T]), timeout=500, verbose=true): Future[T] {.async.} =
  while true:
    let res = tryAwait f()
    if res.isSuccess:
      return res.get
    else:
      echo res
    await asyncSleep(timeout)
