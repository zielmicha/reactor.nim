# TEST.
discard """defer 1
error(err)
defer 1
defer 2
error(error!)"""

import reactor

proc raisingproc() =
  defer:
    echo "defer 1"
  raise newException(ValueError, "error!")

proc myfun() {.async.} =
  defer:
    echo "defer 2"
  raisingproc()

proc myfun2() {.async.} =
  defer:
    echo "defer 1"
  asyncRaise "err"

proc main() {.async.} =
  let res1 = tryAwait myfun2()
  echo res1
  let res2 = tryAwait myfun()
  echo res2

main().runMain
