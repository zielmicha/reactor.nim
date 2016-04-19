import future
import collections/bytes
import collections/lang

export lang
export bytes

export future.`=>`, future.`->`

proc baseBufferSizeFor*[T](v: typedesc[T]): int =
  when v is ref or v is seq or v is string or v is object:
    return 1
  elif not compiles(sizeof(T)):
    return 1
  else:
    when sizeof(T) > 1024:
      return 1
    else:
      return int(1024 / sizeof(v))
