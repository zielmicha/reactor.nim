import reactor/async, reactor/loop

proc foo() {.async.} =
  asyncRaise "an error"

proc bar() {.async.} =
  await foo()

proc main() {.async.} =
  await bar()

main().runMain()
