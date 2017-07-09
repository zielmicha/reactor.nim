import reactor/uv/uv, reactor/uv/uvutil, reactor/util, times

type
  LoopExecutor* = ref object
    uvIdler: ptr uv_idle_t
    callback*: proc()
    enabled: bool

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

proc newLoopExecutor*(): LoopExecutor =
  new(result)
  # TODO(leak)
  result.callback = nothing
  result.enabled = false
  result.uvIdler = cast[ptr uv_idle_t](newUvHandle(UV_IDLE))
  result.uvIdler.data = cast[pointer](result)

  checkZero "idle_init", uv_idle_init(getThreadUvLoop(), result.uvIdler)

proc runLoop*() =
  let loop = getThreadUvLoop()
  checkZero "run", uv_run(loop, UV_RUN_DEFAULT)

proc runLoopOnce*(): bool =
  let loop = getThreadUvLoop()
  let status = uv_run(loop, UV_RUN_ONCE)
  return status != 0

proc stopLoop*() =
  uv_stop(getThreadUvLoop())

proc disableFdInheritance*() =
  uv_disable_stdio_inheritance()

# GC nodelay

var gcNoDelayHandle {.threadvar.}: ptr uv_prepare_t

proc gcSmallCollect() =
  # this should be really cheap if stack is small
  when defined(benchNoDelayGc):
    let start = cpuTime()

  when declared(GC_step):
    GC_step(1_000_000, strongAdvice=true)
  else:
    static:
      echo "[WARN] Using GC_fullCollect"
    GC_fullCollect()

  when defined(benchNoDelayGc):
    echo cpuTime() - start

proc enableGcNoDelay*() =
  ## Enable garbage collection during after event loop tick.
  if gcNoDelayHandle == nil:
    gcNoDelayHandle = cast[ptr uv_prepare_t](newUvHandle(UV_PREPARE))
    checkZero "prepare_init", uv_prepare_init(getThreadUvLoop(), gcNoDelayHandle)
  checkZero "prepare_start", uv_prepare_start(gcNoDelayHandle, proc(handle: ptr uv_prepare_t) {.cdecl.} = gcSmallCollect())
