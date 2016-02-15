# TEST.
discard """yield 0
yield 1
yield 2
yield 3
yield 4
item 0
item 1
item 2
item 3
item 4
yield 0
yield 1
yield 2
yield 3
yield 4
yield 5
yield 6
yield 7
yield 8
yield 9
yield 10
yield 11
yield 12
yield 13
yield 14
yield 15
yield 16
yield 17
yield 18
yield 19
yield 20
yield 21
yield 22
yield 23
yield 24
yield 25
yield 26
yield 27
yield 28
yield 29
yield 30
yield 31
yield 32
recv 0
recv 1
recv 2
recv 3
recv 4
recv 5
recv 6
recv 7
recv 8
recv 9
recv 10
recv 11
recv 12
recv 13
recv 14
recv 15
recv 16
recv 17
recv 18
recv 19
recv 20
recv 21
recv 22
recv 23
recv 24
recv 25
recv 26
recv 27
recv 28
recv 29
recv 30
recv 31
yield 33
yield 34
yield 35
yield 36
yield 37
yield 38
yield 39
recv 32
recv 33
recv 34
recv 35
recv 36
recv 37
recv 38
recv 39"""

import reactor/async, reactor/loop

proc intGenerator(limit: int): Stream[int] {.asyncIterator.} =
  var i = 0
  while i < limit:
    echo "yield ", i
    asyncYield i
    i += 1

intGenerator(5).forEach(proc(item: int) = echo "item ", item).runMain()

proc test1() {.async.} =
  let gen = intGenerator(40)
  asyncFor i in gen:
    echo "recv ", i


test1().runMain()
