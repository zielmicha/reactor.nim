## Helpers for native POSIX calls.
import posix, os, reactor/threading

template retrySyscall*(call: untyped): untyped =
  var r: type(call)
  while true:
    errno = 0
    r = call
    if errno == EINTR:
      continue
    if errno != 0:
      raiseOSError(osLastError())
    break
  r

template spawnSyscall*(call: untyped): untyped =
  spawn(retrySyscall call)
