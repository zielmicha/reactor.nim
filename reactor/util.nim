import future
import endians

export future.`=>`, future.`->`

proc identity*[T](v: T): T {.procvar.} = return v

proc nothing*() {.procvar.} = return

proc nothing1*[T](t: T) {.procvar.} = return

proc baseBufferSizeFor*[T](v: typedesc[T]): int =
  if sizeof(T) > 1024:
    return 1
  else:
    return int(1024 / sizeof(v))

proc convertEndian(size: static[int], dst: pointer, src: pointer, endian=bigEndian) {.inline.} =
  when size == 1:
    copyMem(dst, src, 1)
  else:
    case endian:
    of bigEndian:
      when size == 2:
        bigEndian16(dst, src)
      elif size == 4:
        bigEndian32(dst, src)
      elif size == 8:
        bigEndian64(dst, src)
      else:
        {.error: "Unsupported size".}
    of littleEndian:
      when size == 2:
        littleEndian16(dst, src)
      elif size == 4:
        littleEndian32(dst, src)
      elif size == 8:
        littleEndian64(dst, src)
      else:
        {.error: "Unsupported size".}

proc pack*[T](v: T, endian=bigEndian): string {.inline.} =
  result = newString(sizeof(v))
  convertEndian(sizeof(T), addr result[0], unsafeAddr v)

proc unpack*[T](v: string, t: typedesc[T], endian=bigEndian): T {.inline.} =
  assert v.len == sizeof(T)
  convertEndian(sizeof(T), addr result, unsafeAddr v[0])

#proc unpack*[T](v: array, t: typedesc[T], endian=bigEndian): T {.inline.} =
#  static: assert v.high - v.low + 1 == sizeof(T)
#  convertEndian(addr result, unsafeAddr v[v.low])
