import future

export future.`=>`, future.`->`

proc identity*[T](v: T): T {.procvar.} = return v

proc nothing*() {.procvar.} = return

proc nothing1*[T](t: T) {.procvar.} = return

proc baseBufferSizeFor*[T](v: typedesc[T]): int =
  if sizeof(T) > 1024:
    return 1
  else:
    return int(1024 / sizeof(v))
