type
  BytePipe* = Pipe[byte]
  ByteStream* = Stream[byte]
  ByteProvider* = Provider[byte]

proc forEachChunk*(self: Stream[byte], function: (proc(x: string))): Future[Bottom] =
  self.forEachChunk proc(x: ConstView[byte]) =
    function(x.copyAsString)

proc forEachChunk*(self: Stream[byte], function: (proc(x: string): Future[void])): Future[Bottom] =
  self.forEachChunk proc(x: ConstView[byte]): Future[int] =
    function(x.copyAsString).then(proc(): int = x.len)
