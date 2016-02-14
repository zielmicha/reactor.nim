import reactor/async, reactor/loop

proc foo() {.async.} =
  asyncRaise "an error"

proc bar() {.async.} =
  await foo()

proc main() {.async.} =
  #await bar()
  let fut = tryAwait bar()
  fut.error.printError

main().runLoop()
