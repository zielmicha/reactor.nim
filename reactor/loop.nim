include reactor/uv/uvloop

type
  LoopExecutorWithArg*[T] = ref object
    callback*: proc(t: T)
    arg*: T
    executor: LoopExecutor

proc enable*(self: LoopExecutorWithArg) =
  self.executor.enable()

proc newLoopExecutorWithArg*[T](): LoopExecutorWithArg[T] =
  let self = new(LoopExecutorWithArg[T])
  self.executor = newLoopExecutor()
  self.callback = proc(t: T) = return
  proc callback() = self.callback(self.arg)

  self.executor.callback = callback
  return self
