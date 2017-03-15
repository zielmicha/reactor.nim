import reactor

proc foo(n: int) {.async.} =
  if n == 0:
    raise newException(Exception, "hello")
  await foo(n - 1)

foo(4).runMain
