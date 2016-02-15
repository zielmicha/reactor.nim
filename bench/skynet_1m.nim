import reactor/async, reactor/loop

proc skynetAsync(num: int, size: int, divi: int): Future[int] {.async.} =
  if size == 1:
    return num
  else:
    var tasks: seq[Future[int]] = @[]
    for i in 0..<divi:
      let subNum = num + i * (size div divi)
      tasks.add skynetAsync(subNum, size div divi, divi)

    var counter = 0
    for task in tasks:
      counter += await task
    return counter

echo "running..."
let res = skynetAsync(0, 1000000, 10).runLoop()
echo res
