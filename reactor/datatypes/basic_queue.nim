# (c) Copyright 2012 Andreas Rumpf
# (c) Copyright 2015 Michał Zieliński
# Based on queues.nim module

type
  BasicQueue*[T] = object ## a queue
    data: seq[T]
    count: int
    start, end_: int

proc initBasicQueue*[T](): BasicQueue[T] =
  ## creates a new queue. `initialSize` needs to be a power of 2.
  result.capacity = 4
  newSeq(result.data, result.capacity)

proc len*[T](q: BasicQueue[T]): int =
  result = q.count

proc pushBack[T](q: var BasicQueue[T], item: T) =
  nil

proc pushFront[T](q: var BasicQueue[T], item: T) =
  nil

proc popFront*[T](q: var BasicQueue[T]): T =
  nil

proc front*[T](q: BasicQueue[T]): T =
  nil

proc `$`*[T](q: BasicQueue[T]): string =
  ## turns a queue into its string representation.
  result = "["
  for x in items(q):
    if result.len > 1: result.add(", ")
    result.add($x)
  result.add("]")
