# TEST.
discard """hello 4
hello 5
hello 2
hello 1
just(...)"""
import reactor

proc main() {.async.} =
  defer: echo "hello 1"
  defer:
    echo "hello 2"
  echo "hello 4"
  await asyncSleep(10)
  echo "hello 5"

proc mainWrapper() {.async.} =
  let r = tryAwait main()
  echo r

mainWrapper().runMain()
