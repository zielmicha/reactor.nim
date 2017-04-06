# TEST.
discard """hello 3
hello 2
hello 1
error(err)"""
import reactor/tcp, reactor/loop, reactor/async, reactor/util, reactor/ipaddress, reactor/time

proc raiseErr(): Future[void] =
  return now(error(void, "err"))

proc main() {.async.} =
  defer: echo "hello 1"
  defer: echo "hello 2"
  echo "hello 3"
  await raiseErr()
  echo "hello 4"
  defer: echo "hello 5"
  echo "hello 6"

proc mainWrapper() {.async.} =
  let r = tryAwait main()
  echo r

mainWrapper().runMain()
