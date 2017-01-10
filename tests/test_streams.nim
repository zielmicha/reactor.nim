# TEST.
discard """read hello
more X"""
import reactor/async, reactor/loop

proc main() {.async.} =
  let (stream, provider) = newInputOutputPair[byte]()
  let writeFut = provider.write("\0\0\0\x05helloX")
  let data = await stream.readChunkPrefixed()
  echo "read ", data
  echo "more ", await stream.read(1)
  await writeFut

main().ignore()
runLoop()
