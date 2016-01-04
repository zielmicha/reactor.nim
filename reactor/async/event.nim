
type
  CallbackId* = int64

  Event*[T] = ref object
    callbacks: Table[CallbackId, proc(arg: T)]
    nextId: CallbackId
    executor: LoopExecutor

proc newEvent*[T](): Event[T] =
  newEvent(result)

proc newEvent*[T](t: var Event[T]) =
  new(t)
  t.callbacks = initTable[CallbackId, proc(arg: T)]()
  t.executor = newLoopExecutor()

proc addListener*[T](ev: Event[T], callback: proc(arg: T)): CallbackId {.discardable.} =
  result = ev.nextId
  ev.nextId += 1
  ev.callbacks[result] = callback

proc addListener*(ev: Event[void], callback: proc()): CallbackId {.discardable.} =
  addListener[void](ev, callback)

proc removeListener*[T](ev: Event[T], evId: CallbackId) =
  if evId in ev.callbacks:
    ev.callbacks.del(evId)

proc removeAllListeners*[T](ev: Event[T]) =
  ev.callbacks = initTable[CallbackId, proc(arg: T)]()

proc callListenerNow*[T](ev: Event[T], arg: T) =
  for k, v in ev.callbacks.pairs:
    when T is void:
      v()
    else:
      v(arg)

proc callListener*[T](ev: Event[T], arg: T) =
  ev.executor.callback = proc() = ev.callListenerNow(arg)
  ev.executor.enable()

proc callListener*(ev: Event[void]) =
  ev.executor.callback = proc() = callListenerNow[void](ev)
  ev.executor.enable()
