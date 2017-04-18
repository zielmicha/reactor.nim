import reactor/uv/uv, reactor/uv/uvutil, reactor/loop, reactor/async
import cpuinfo, locks, os

type
  ThreadFunc = object
    function: (proc() {.gcsafe.})

  ThreadState = object
    number: int
    channel: Channel[ThreadFunc]
    channelReady: ptr uv_async_t
    ready: Lock

  MultiLoop = ref object
    threads: seq[Thread[ptr ThreadState]]
    state: seq[ThreadState]


var mloop: MultiLoop = nil
var currentThreadState {.threadvar.}: ptr ThreadState

proc threadLoopCount*(): int =
  mloop.state.len

proc threadLoopId*(): int =
  if currentThreadState == nil:
    raise newException(Exception, "not in multiloop thread")

  currentThreadState.number

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

proc runOnThread*(threadId: int, function: (proc() {.gcsafe.})) =
  ## Execute ``function`` on thread ``threadId``. This function returns immediatly.
  if currentThreadState != nil and threadId == threadLoopId():
    function()
  else:
    mloop.state[threadId].channel.send(ThreadFunc(function: function))
    checkZero "async_send", uv_async_send(mloop.state[threadId].channelReady)

proc runOnAllThreads*(function: (proc() {.gcsafe.})) =
  for i in 0..<threadLoopCount():
    runOnThread(i, function)

proc startMultiloop*(threadCount: int=0, pin: bool=true, mainProc: proc(): Future[void] {.gcsafe.}=nil) =
  ## Create new MultiLoop. Starts ``threadCount`` IO loops and runs event loops in them.
  ## Later, you can execute code in them using ``execOnThread`` and ``execOnAllThreads``.
  ##
  ## ``threadCount`` by default equals number of cores.
  ##
  ## If ``pin`` is true, each thread will have affinity set to core with the same number
  ## as its number.
  let threadCount = if threadCount == 0: cpuinfo.countProcessors()
                    else: threadCount

  new(mloop)
  mloop.threads = newSeq[Thread[ptr ThreadState]](threadCount)
  mloop.state = newSeq[ThreadState](threadCount)

  for i in 0..<threadCount:
    mloop.state[i].number = i
    mloop.state[i].channel.open
    mloop.state[i].ready.initLock
    mloop.state[i].ready.acquire
    createThread(mloop.threads[i], loopMain, addr mloop.state[i])

  # wait for threads to finish initialization
  for i in 0..<threadCount:
    mloop.state[i].ready.acquire

  if mainProc != nil:
    # start
    runOnAllThreads(proc() = mainProc().runMain)

    for i in 0..<threadCount:
      mloop.threads[i].joinThread

proc execOnThread*[T](threadId: int, function: (proc(): Future[T] {.gcsafe.})): Future[T] =
  let completer = newCompleter[T]()
  let myId = threadLoopId()

  proc finish(r: Result[T]) =
    runOnThread(myId, proc() = completer.complete(r))

  runOnThread(threadId, proc() = function().onSuccessOrError(finish))
  return completer.getFuture
