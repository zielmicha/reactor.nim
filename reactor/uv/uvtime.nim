import reactor/async, reactor/uv/uvutil, reactor/uv/uv

proc asyncSleep*(timeout: int64): Future[void] =
  let completer = newCompleter[void]()
  let handle = cast[ptr uv_timer_t](newUvHandle(UV_TIMER))
  checkZero "timer_init", uv_timer_init(getThreadUvLoop(), handle)
  GC_ref(completer)
  handle.data = cast[pointer](completer)

  proc timerCb(handle: ptr uv_timer_t) {.cdecl.} =
    let completer = cast[Completer[void]](handle.data)
    handle.data = nil
    completer.complete()
    GC_unref(completer)
    uv_close(handle, freeUvMemory)

  checkZero "timer_init", uv_timer_start(handle, timerCb, max(0, timeout).uint64, 0)

  return completer.getFuture
