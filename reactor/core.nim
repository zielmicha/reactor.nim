import reactor/async

type
  ByteStream* = Stream[byte]
  ByteProvider* = Provider[byte]

  File* = ref object {.inheritable.}
    input*: ByteStream
    output*: ByteProvider
