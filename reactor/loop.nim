import reactor/uv/uv, reactor/uv/uvutil, reactor/util

type
  LoopExecutor* = ref object
    uvIdler: ptr uv_idle_t
    callback*: proc()
    enabled: bool

  LoopExecutorWithArg*[T] = ref object
    callback*: proc(t: T)
    arg*: T
    executor: LoopExecutor

proc disable*(self: LoopExecutor) =
  if not self.enabled:
    return

  GC_unref(self)
  self.enabled = false
  checkZero "idle_stop", uv_idle_stop(self.uvIdler)

proc uvCallback(handle: ptr uv_idle_t) {.cdecl.} =
  uvTopCallback:
    let self = cast[LoopExecutor](handle.data)
    self.disable()
    self.callback()

proc enable*(self: LoopExecutor) =
  if self.enabled:
    return

  GC_ref(self) # will be called by the loop
  # FIXME: what happens when loop dies before executing the callback?
  self.enabled = true
  checkZero "idle_start", uv_idle_start(self.uvIdler, uvCallback)

proc enable*(self: LoopExecutorWithArg) =
  self.executor.enable()

proc newLoopExecutor*(): LoopExecutor =
  new(result)
  result.callback = nothing
  result.enabled = false
  result.uvIdler = cast[ptr uv_idle_t](newUvHandle(UV_IDLE))
  result.uvIdler.data = cast[pointer](result)

  checkZero "idle_init", uv_idle_init(getThreadUvLoop(), result.uvIdler)

proc newLoopExecutorWithArg*[T](): LoopExecutorWithArg[T] =
  let self = new(LoopExecutorWithArg[T])
  self.executor = newLoopExecutor()
  self.callback = proc(t: T) = return
  proc callback() = self.callback(self.arg)

  self.executor.callback = callback
  return self

proc runLoop*() =
  let loop = getThreadUvLoop()
  checkZero "run", uv_run(loop, UV_RUN_DEFAULT)
