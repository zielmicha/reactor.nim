import reactor/datatypes/basic
import lists, strutils

type
  QueueChunk[T] = object
    data: seq[T]
    begin: int
    `end`: int

  Queue*[T] = ref object
    chunkSize: int
    size: int

    list: DoublyLinkedList[QueueChunk[T]]

proc newQueue*[T](chunkSize=4096): Queue[T] =
  new(result)
  result.chunkSize = chunkSize
  result.list = initDoublyLinkedList[QueueChunk[T]]()

proc initChunk[T](queue: Queue[T]): QueueChunk[T] =
  result.data = newSeq[T](queue.chunkSize)
  result.begin = 0
  result.`end` = 0

proc len*(queue: Queue): int =
  return queue.size

proc pushBackMany*[T](queue: Queue[T], items: ConstView[T]) =
  if queue.list.tail == nil:
    queue.list.append(queue.initChunk())

  var index: int = 0
  while true:
    var tail = queue.list.tail
    let copySize = min(queue.chunkSize - tail.value.`end`, items.len - index)

    if copySize != 0:
      tail.value.data.seqView.slice(tail.value.`end`).copyFrom(items.slice(index, copySize))
      tail.value.`end` += copySize
      queue.size += copySize
      index += copySize

    if index >= items.len:
      break

    queue.list.append(queue.initChunk())

proc pushBack*[T](queue: Queue[T], item: T) =
  var itemI = item
  queue.pushBackMany(singleItemView(itemI))

proc peekFrontMany*[T](queue: Queue[T]): ConstView[T] =
  if queue.list.head == nil:
    return emptyView[T]().viewToConstView

  let head = queue.list.head

  return seqView(head.value.data).slice(head.value.begin, head.value.`end` - head.value.begin).viewToConstView

proc popFront*[T](queue: Queue[T], count=1) =
  var count = count
  while count > 0:
    let head = queue.list.head
    let maxPop = head.value.`end` - head.value.begin
    let doPop = min(maxPop, count)
    count -= doPop
    queue.size -= doPop
    if maxPop == doPop:
      queue.list.remove(queue.list.head)
    else:
      head.value.begin += doPop

proc `$`*[T](queue: Queue[T]): string =
  var s: seq[string] = @[]
  for chunk in queue.list:
    for i in chunk.begin..<chunk.`end`:
      s.add($(chunk.data[i]))
  "Queue(chunkSize=$1, size=$2, [$3])" % [$queue.chunkSize, $queue.size, s.join(", ")]

when isMainModule:
  let q = newQueue[int](chunkSize=4)
  for i in 1..10:
    echo q
    q.pushBack(i)

  echo q

  for i in 1..9:
    q.popFront()
    echo q

  for i in 1..10:
    q.pushBack(i)
    echo q
