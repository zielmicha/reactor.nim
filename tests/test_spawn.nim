# TEST.
discard """hard work started
hard work finished
hard work returned 5"""
import reactor/loop, reactor/async, reactor/threading, os

proc hardWork(): int =
  sleep(100)
  echo "hard work finished"
  return 5

proc main() {.async.} =
  let f = spawn hardWork()
  echo "hard work started"
  let v = await f
  echo "hard work returned ", v

main().runLoop()
