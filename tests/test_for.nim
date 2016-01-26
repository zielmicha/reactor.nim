# TEST.
discard """item 1
item 2
item 3
here"""

import reactor/async, reactor/loop, future

proc simplePipe(src: Stream[int]) {.async.} =
   asyncFor item in src:
     echo "item ", item
   echo "here"

let (s, p) = newStreamProviderPair[int]()
p.provideAll(@[1, 2, 3]).then(() => p.sendClose(JustClose)).ignore

simplePipe(s).ignoreError(CloseException).runLoop()
