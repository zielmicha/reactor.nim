# TEST.
discard """read hello"""
import reactor/async, reactor/loop

proc main() {.async.} =
  let (stream, provider) = newStreamProviderPair[byte]()
  let writeFut = provider.write("\0\0\0\x05hello")
  let data = await stream.readChunkPrefixed()
  echo "read ", data
  await writeFut

main().ignore()
runLoop()
