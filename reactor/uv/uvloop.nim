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

# signals

proc addSignalHandler*(signal: cint, callback: proc()) =
  let handle = cast[ptr uv_signal_t](newUvHandle(UV_SIGNAL))
  checkZero "signal_init", uv_signal_init(getThreadUvLoop(), handle)

  type CallbackWrapper = ref object
    callback: proc()

  let wrapper = CallbackWrapper(callback: callback)
  GC_ref(wrapper)
  handle.data = cast[pointer](wrapper)

  proc cb(handle: ptr uv_signal_t, signum: cint) {.cdecl.} =
    cast[CallbackWrapper](handle.data).callback()

  checkZero "signal_start", uv_signal_start(handle, cb, signal)

# ThreadsafeQueue

type
  ThreadsafeQueueVal[T] = object
    cb: proc(val: T)
    channel: Channel[T]
    channelReady: ptr uv_async_t

  ThreadsafeQueue*[T] = ptr ThreadsafeQueueVal[T]

proc queueMessageReady[T](req: ptr uv_async_t) {.cdecl.} =
  let q = cast[ThreadsafeQueue[T]](req.data)
  while q.channel.peek > 0: # this is safe to use, we are the only recver
    let data = q.channel.recv
    q.cb(data)

proc newThreadsafeQueue*[T](cb: proc(val: T)): ThreadsafeQueue[T] =
  result = create(ThreadsafeQueueVal[T])
  result.cb = cb
  result.channel.open
  result.channelReady = cast[ptr uv_async_t](newUvHandle(UV_ASYNC))
  result.channelReady.data = result
  checkZero "async_init", uv_async_init(getThreadUvLoop(), result.channelReady, queueMessageReady[T])

proc sendThreadsafe*[T](self: ThreadsafeQueue[T], value: T) =
  self.channel.send(value)
  checkZero "async_send", uv_async_send(self.channelReady)

# GC nodelay

var gcNoDelayHandle {.threadvar.}: ptr uv_prepare_t

proc gcSmallCollect() =
  # this should be really cheap if stack is small
  when defined(benchNoDelayGc):
    let start = cpuTime()

  when declared(GC_step):
    GC_step(1_000_000, strongAdvice=true)
  else:
    stderr.writeLine "[WARN] Using GC_fullCollect"
    GC_fullCollect()

  when defined(benchNoDelayGc):
    echo cpuTime() - start

proc enableGcNoDelay*() =
  ## Enable garbage collection during after event loop tick.
  if gcNoDelayHandle == nil:
    gcNoDelayHandle = cast[ptr uv_prepare_t](newUvHandle(UV_PREPARE))
    checkZero "prepare_init", uv_prepare_init(getThreadUvLoop(), gcNoDelayHandle)
  checkZero "prepare_start", uv_prepare_start(gcNoDelayHandle, proc(handle: ptr uv_prepare_t) {.cdecl.} = gcSmallCollect())
