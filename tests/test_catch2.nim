import reactor

proc raisingproc() =
  defer:
    echo "defer 1"
  raise newException(ValueError, "error!")

proc myfun() {.async.} =
  defer:
    echo "defer 2"
  raisingproc()

proc main() {.async.} =
  await myfun()

main().runMain
