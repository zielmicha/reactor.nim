# TEST. Expected output:
discard """start add5
got a 5
got b 1
returned 6
returned 10
start add5
got a 5
Error in ignored future: boom!"""

import reactor/async, reactor/loop

proc add5(num: Future[int]): Future[int] {.async.} =
  proc somelambda(): int =
    # check if this "return" is not replaced
    return 5

  assert somelambda() == 5

  echo "start add5"
  let a = await now(just(5))
  echo "got a ", a
  let b = await num
  echo "got b ", b
  return a + b

proc add5bis(s: Future[int]): Future[int] {.async.} =
  return (await s) + 5

proc foo() {.async.} =
  discard

let my1 = newCompleter[int]()
let my6 = add5(my1.getFuture)
my1.complete(1)
my6.then(proc(x: int) = echo "returned ", x).ignore()

add5bis(now(just(5))).then(proc(x: int) = echo "returned ", x).ignore()

add5(now(error(int, "boom!"))).ignore()

foo().ignore()

runLoop()
