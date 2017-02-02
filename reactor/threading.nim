import reactor/async
import reactor/uv/uvthreadpool
import reactor/uv/uvthreads

export execInPool

template maybeWrapResult(e): expr =
  when e is Result:
    e
  else:
    just(e)

template spawn*(e: expr): expr =
  execInPool(proc(): auto = maybeWrapResult(e))
