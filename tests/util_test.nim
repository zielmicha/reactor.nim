import reactor

proc testLeaks*(p: proc(): Future[void]) {.async.} =
  var memHistory: seq[int]
  for i in 0..10:
    await p()
    GC_fullCollect()
    memHistory.add getOccupiedMem()

  let noLeaks = (min(memHistory).float * 1.5) > max(memHistory).float
  doAssert noLeaks
