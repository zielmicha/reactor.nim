### FIXME
* async procs may cause stack overflow in some situations
* queue chunk size is always 4096
* JustClose in i.e. receiveAll should be chaned to EofError
* `return` in async without value in nonvoid proc crashes compiler

### TODO
* optimize `then` for immediate futures
* close UV streams
* stacktraces in futures
* add variant of `map` for function returning `Future`s
* `TaskQueue` for cancellation and concurrency limitation
* slice should probably use doAssert
* show all currently running coroutines
* Future should be non nil or something

### TODO (asyncmacro)
* `yield` to `asyncYield`
* add try-except support
* (possibly) catch all other exceptions and convert to async failure
* rewriting of returns inside asyncReturn
