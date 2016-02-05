### FIXME
* async procs may cause stack overflow in some situations
* queue chunk size is always 4096

### TODO
* optimize `then` for immediate futures
* close UV streams
* stacktraces in futures
* add variant of `map` for function returning `Future`s
* `TaskQueue` for cancellation and concurrency limitation

### TODO (asyncmacro)
* change `return` to `asyncReturn`, `yield` to `asyncYield`
* add try-except support
* (possibly) catch all other exceptions and convert to async failure
