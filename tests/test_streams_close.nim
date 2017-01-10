# TEST.
discard """@[5, 6]
@[5]
@[6]
1
2
3
Error in ignored future

Asynchronous trace:
test_streams_close.nim(44) test3

Error: reader closed [Exception]"""

import reactor/async, reactor/loop

proc test1() {.async.} =
  let (stream, provider) = newInputOutputPair[int]()

  await provider.provide(5)
  await provider.provide(6)
  provider.sendClose(JustClose)

  (await stream.receiveAll(2)).echo

proc test2() {.async.} =
  let (stream, provider) = newInputOutputPair[int]()

  await provider.provide(5)
  await provider.provide(6)
  provider.sendClose(JustClose)

  (await stream.receiveAll(1)).echo
  (await stream.receiveSome(10)).echo

proc test3() {.async.} =
  let (stream, provider) = newInputOutputPair[int]()

  echo "1"
  await provider.provide(1)
  echo "2"
  stream.recvClose(newException(ValueError, "reader closed"))
  echo "3"
  await provider.provide(5)
  echo "4"

test1().ignore()
test2().ignore()
test3().ignore()
runLoop()
