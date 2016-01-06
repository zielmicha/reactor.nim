# TEST.
discard """start add5
got a 5
got b 1
returned 6"""

import reactor/async, reactor/loop

proc add5(num: Future[int]): Future[int] =
   let asyncProcCompleter = newCompleter[int]()

   template await(e: expr): expr = awaitInIterator(e)
   template asyncReturn(e: expr): expr =
     asyncProcCompleter.complete(e)
     return

   let iter = iterator(): AsyncIterator {.closure.} =
     echo "start add5"
     let a = await immediateFuture(5)
     echo "got a ", a
     let b = await num
     echo "got b ", b
     asyncReturn a + b
     echo "not executed"

   asyncIteratorRun(iter)
   return asyncProcCompleter.getFuture

let my1 = newCompleter[int]()
let my6 = add5(my1.getFuture)
my1.complete(1)
my6.then(proc(x: int) = echo "returned ", x).ignore()

runLoop()
