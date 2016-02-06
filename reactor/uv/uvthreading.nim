# this must be a separate module to avoid conflict with threadpool await
from reactor/async import Completer, complete, Future, newCompleter
from threadpool import nil
import reactor/uv/uv, reactor/uv/uvutil

type ExecState[T] = ref object
  completer: Completer[T]
  flowVar: threadpool.FlowVar[T]

proc execFinished[T](req: ptr uv_async_t) {.cdecl.} =
  let state = cast[ExecState[T]](req.data)
  let result = threadpool.`^`(state.flowVar)
  state.completer.complete(result)
  GC_unref(state)
  req.data = nil
  uv_close(req, freeUvMemory)

proc inPool[T](req: ptr uv_async_t, function: (proc(): T)): T =
  result = function()
  checkZero "async_send", uv_async_send(req)

proc execInPool*[T](function: (proc(): T)): Future[T] =
  let state = ExecState[T](completer: newCompleter[T]())
  let req = cast[ptr uv_async_t](newUvHandle(UV_ASYNC))
  GC_ref(state)
  checkZero "async_init", uv_async_init(getThreadUvLoop(), req, execFinished[T])
  req.data = cast[pointer](state)

  state.flowVar = threadpool.spawn(inPool(req, function))
  return state.completer.getFuture

template spawn*(e: expr): expr =
  execInPool(proc(): auto = e)
