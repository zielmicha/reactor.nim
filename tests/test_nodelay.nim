# TEST.
discard """foo deleted
done"""
import reactor

type Foo = object

proc foo_deleted(m: ref Foo) =
  echo "foo deleted"

proc main() {.async.} =
  enableGcNoDelay()
  var f: ref Foo
  new(f, foo_deleted)
  f = nil
  await asyncSleep(10)
  echo "done"

main().runMain()
