
type
  View*[T] = object
    data: ptr T
    size: int

  ConstView*[T] = object
    data: ptr T
    size: int

  SomeView*[T] = View[T] | ConstView[T]

proc emptyView*[T](): View[T] =
  result.data = nil
  result.size = 0

proc singleItemView*[T](item: var T): View[T] =
  View[T](data: addr item, size: 1)

converter seqView*[T](s: var seq[T]): View[T] =
  result.data = addr s[0]
  result.size = s.len

converter viewToConstView*[T](v: View[T]): ConstView[T] =
  result.data = v.data
  result.size = v.size

proc len*(v: SomeView): int =
  v.size

proc asPointer*[T](v: SomeView[T]): ptr T =
  v.data

proc ptrAdd[T](p: ptr T, i: int): ptr T =
  return cast[ptr T](cast[int](p) +% (i * sizeof(T)))

proc `[]`*[T](v: ConstView[T], i: int): T =
  assert(i >= 0 and i < v.size)
  return ptrAdd(v.data + i)[]

proc `[]`*[T](v: View[T], i: int): var T =
  assert(i >= 0 and i < v.size)
  return ptrAdd(v.data + i)[]

proc slice*[T](v: SomeView[T], start: int, size: int): SomeView[T] =
  assert start < v.len and start >= 0
  assert size >= 0 and start + size <= v.len
  result.data = ptrAdd(v.data, start)
  result.size = size

proc slice*[T](v: SomeView[T], start: int): SomeView[T] =
  assert start < v.len and start >= 0
  return v.slice(start, v.len - start)

proc copyFrom*[T](dst: View[T], src: SomeView[T]) =
  assert dst.size >= src.size
  when T is int or T is byte:
    copyMem(dst.data, src.data, src.size * sizeof(T))
  else:
    for i in 0..<src.size:
      ptrAdd(dst.data, i)[] = ptrAdd(src.data, i)[]

proc copyTo*[T](src: SomeView[T], dst: View[T]) =
  dst.copyFrom(src)

proc copyAsSeq*[T](src: SomeView[T]): seq[T] =
  result.setLen(src.len)
  src.copyTo(result)
