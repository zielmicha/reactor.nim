import reactor/async
import reactor/uv/uvthreadpool
import reactor/uv/uvmultithread

export execInPool
export uvmultithread

template maybeWrapResult(e): untyped =
  when e is Result:
    e
  else:
    just(e)

template spawn*(e: typed): untyped =
  ## Be cautionous when using this function to not capture too much, as everything captured will be copied to worker thread.
  execInPool(proc(): auto = maybeWrapResult(e))
