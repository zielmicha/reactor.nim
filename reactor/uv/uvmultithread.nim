import reactor/uv/uv, reactor/uv/uvutil, reactor/loop
import cpuinfo, locks, os

type
  ThreadFunc = object
    function: (proc() {.gcsafe.})

  ThreadState = object
    number: int
    channel: Channel[ThreadFunc]
    channelReady: ptr uv_async_t
    ready: Lock

  MultiLoop* = ref object
    threads: seq[Thread[ptr ThreadState]]
    state: seq[ThreadState]

var currentThreadState {.threadvar.}: ptr ThreadState

proc channelMessageReady(req: ptr uv_async_t) {.cdecl.} =
  while currentThreadState.channel.peek > 0: # this is safe to use, we are the only recver
    let funcWrapper = currentThreadState.channel.recv
    funcWrapper.function()
    
proc loopMain(state: ptr ThreadState) {.thread.} =
  currentThreadState = state
  initThreadLoop()
  state.channelReady = cast[ptr uv_async_t](newUvHandle(UV_ASYNC))
  checkZero "async_init", uv_async_init(getThreadUvLoop(), state.channelReady, channelMessageReady)
  state.ready.release
  runLoop()

proc newMultiLoop*(threadCount: int=0, pin: bool=true): MultiLoop =
  ## Create new MultiLoop. Starts ``threadCount`` IO loops and runs event loops in them.
  ## Later, you can execute code in them using ``execOnThread`` and ``execOnAllThreads``.
  ##
  ## ``threadCount`` by default equals number of cores.
  ##
  ## If ``pin`` is true, each thread will have affinity set to core with the same number
  ## as its number.
  let threadCount = if threadCount == 0: cpuinfo.countProcessors()
                    else: threadCount

  new(result)
  result.threads = newSeq[Thread[ptr ThreadState]](threadCount)
  result.state = newSeq[ThreadState](threadCount)

  for i in 0..<threadCount:
    result.state[i].number = i
    result.state[i].channel.open
    result.state[i].ready.initLock
    result.state[i].ready.acquire
    createThread(result.threads[i], loopMain, addr result.state[i])

  # wait for threads to finish initialization
  for i in 0..<threadCount:
    result.state[i].ready.acquire

proc execOnThread*(m: MultiLoop, threadId: int, function: (proc() {.gcsafe.})) =
  m.state[threadId].channel.send(ThreadFunc(function: function))
  checkZero "async_send", uv_async_send(m.state[threadId].channelReady)

proc threadCount*(m: MultiLoop): int =
  m.state.len

proc execOnAllThreads*(m: MultiLoop, function: (proc() {.gcsafe.})) =
  for i in 0..<m.threadCount:
    m.execOnThread(i, function)

proc threadLoopId*(): int =
  if currentThreadState == nil:
    raise newException(Exception, "not in multiloop thread (probably in main thread?)")

  currentThreadState.number
