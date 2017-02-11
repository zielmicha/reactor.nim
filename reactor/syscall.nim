## Helpers for native POSIX calls.
import posix, os

template retrySyscall*(call: untyped): untyped =
  var r: cint
  while true:
    r = call
    if errno == EINTR:
      continue
    if errno != 0:
      raiseOSError(osLastError())
    break
  r
