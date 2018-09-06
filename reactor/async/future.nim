# included from reactor/async.nim
## A `Future` represents the result of an asynchronous computation. `Completer` is used to create and complete Futures - it can be thought as of an other side of a Future.

type
  FutureCallback[T] = (proc(data: RootRef, future: Completer[T]) {.closure.})

  CallbackList[T] = ref object
    next: CallbackList[T]
    callback: FutureCallback[T]

  Future*[T] = object {.requiresinit.}
    # Future can either be completed immediately or 'later'.
    # The first case is only an optimization.
    case isImmediate: bool
    of true:
      value: T
    of false:
      completer: Completer[T]

  Completer*[T] = ref object of RootObj
    when debugFutures:
      stackTrace: string

    consumed: bool

    case isFinished: bool
    of true:
      result: Result[T]
    of false:
      callback: FutureCallback[T]
      callbackList: CallbackList[T]

  Bottom* = object

proc makeInfo[T](f: Future[T]): string =
  if f.isImmediate:
    return "immediate"
  else:
    let c = f.completer
    result = ""
    if c.isFinished:
      if c.consumed:
        result &= "consumed "
      result &= $c.result
    else:
      result &= "unfinished"

proc `$`*[T](c: Future[T]): string =
  "Future " & makeInfo(c)

proc `$`*[T](c: Completer[T]): string =
  var listenerCount = 0
  if not c.isFinished and c.callback != nil:
    listenerCount = 1
    var curr = c.callbackList
    while curr != nil:
      listenerCount += 1
      curr = curr.next
  return "Completer $1 listener-count: $2" % [makeInfo(c.getFuture), $listenerCount]

proc checkValid*(f: Future) =
  doAssert f.isImmediate or f.completer != nil

proc getFuture*[T](c: Completer[T]): Future[T] =
  ## Retrieves a Future managed by the Completer.
  Future[T](isImmediate: false, completer: c)

proc internalGetCompleter*[T](c: Future[T]): Completer[T] =
  ## Retrieves a Completer behind this Future. Returns `nil` is the future is immediate.
  ## Only for low-level use.
  if c.isImmediate:
    return nil
  else:
    return c.completer

proc destroyCompleter[T](f: Completer[T]) =
  if not f.consumed and f.isFinished and f.result.isError:
    when not defined(reactorIgnoreUnconsumedFutures):
      stderr.writeLine "Destroyed unconsumed future ", $f.getFuture
      when debugFutures:
        stderr.writeLine f.stackTrace

proc newCompleter*[T](): Completer[T] =
  ## Creates a new completer.
  new(result, destroyCompleter[T])
  result.isFinished = false
  when debugFutures:
    result.stackTrace = getStackTrace()

proc addCallback[T](c: Completer[T], cb: FutureCallback[T]) =
  if c.callback == nil:
    c.callback = cb
  else:
    let newList = CallbackList[T](callback: cb, next: c.callbackList)
    c.callbackList = newList

converter now*[T](res: Result[T]): Future[T] =
  ## Returns already completed Future containing result `res`.
  if res.isSuccess:
    when T is void:
      return Future[T](isImmediate: true)
    else:
      return Future[T](isImmediate: true, value: res.value)
  else:
    return Future[T](isImmediate: false, completer: Completer[T](isFinished: true, result: res))

proc immediateFuture*[T](value: T): Future[T] {.deprecated.} =
  let r = just(value)
  return now(r)

proc immediateFuture*(): Future[void] {.deprecated.} =
  now(just())

proc immediateError*[T](value: string): Future[T] {.deprecated.} =
  now(error(T, value))

proc immediateError*[T](value: ref Exception): Future[T] {.deprecated.} =
  now(error(T, value))

proc isCompleted*(self: Future): bool =
  ## Checks if a Future is completed.
  return self.isImmediate or self.completer.isFinished

proc isSuccess*(self: Future): bool =
  ## Checks if a Future is completed and doesn't contain an error.
  return self.isImmediate or (self.completer.isFinished and self.completer.result.isSuccess)

proc getResult*[T](self: Future[T]): Result[T] =
  ## Returns the result represented by a completed Future.
  if self.isImmediate:
    when T is not void:
      return just(self.value)
    else:
      return just()
  else:
    assert self.completer.isFinished
    self.completer.consumed = true
    return self.completer.result

proc get*[T](self: Future[T]): T =
  ## Returns the value represented by a completed Future.
  ## If the Future contains an error, raise it as an exception.
  if self.isImmediate:
    when T is not void:
      return self.value
  else:
    assert self.completer.isFinished
    self.completer.consumed = true
    when T is void:
      self.completer.result.get
    else:
      return self.completer.result.get

proc completeResult*[T](self: Completer[T], x: Result[T]) =
  ## Complete a Future managed by the Completer with result `x`.
  assert(not self.isFinished)
  let callback = self.callback
  var callbackList = self.callbackList

  self.callback = nil
  self.callbackList = nil

  self.isFinished = true
  self.result = x

  if callback != nil:
    callback(nil, self)

  while callbackList != nil:
    callbackList.callback(nil, self)
    callbackList = callbackList.next

proc complete*[T](self: Completer[T], x: T) =
  ## Complete a Future managed by the Completer with value `x`.
  self.completeResult(just(x))

proc complete*(self: Completer[void]) =
  ## Complete a void Future managed by the Completer.
  completeResult[void](self, just())

proc completeError*[T](self: Completer[T], x: ref Exception) =
  ## Complete a Future managed by the Completer with error `x`.
  self.completeResult(error(T, x))

proc onSuccessOrError*[T](f: Future[T], onSuccess: (proc(t:T)), onError: (proc(t:ref Exception))) =
  ## Call `onSuccess` or `onError` when Future is completed. If Future is already completed, one of these functions is called immediately.
  if f.isImmediate:
    when T is void:
      onSuccess()
    else:
      onSuccess(f.value)
    return

  let c = f.completer
  assert c != nil
  c.consumed = true
  if c.isFinished:
    onSuccessOrErrorR[T](c.result, onSuccess, onError)
  else:
    c.addCallback(
      (proc(data: RootRef, compl: Completer[T]) =
         onSuccessOrError[T](f, onSuccess, onError)))

proc onSuccessOrError*(f: Future[void], onSuccess: (proc()), onError: (proc(t:ref Exception))) =
  onSuccessOrError[void](f, onSuccess, onError)

proc onSuccessOrError*(f: Future[void], function: (proc(t: Result[void]))) =
  onSuccessOrError(f,
    proc() = function(just()),
    proc(exc: ref Exception) = function(error(void, exc)))

proc onSuccessOrError*[T](f: Future[T], function: (proc(t: Result[T]))) =
  onSuccessOrError(f,
    (proc(t: T) = function(when T is void: just() else: just(t))),
    proc(exc: ref Exception) = function(error(T, exc)))

proc onError*(f: Future[Bottom], onError: (proc(t: ref Exception))) =
  onSuccessOrError(f, nil, onError)

proc ignoreResult*[T](f: Future[T]): Future[Bottom] =
  let completer = newCompleter[Bottom]()

  onSuccessOrError[T](f, onSuccess=nothing1[T],
                      onError=proc(t: ref Exception) = completeError(completer, t))

  return completer.getFuture

proc ignoreResultValue*[T](f: Future[T]): Future[void] =
  return f.then(proc(x: T) = discard)

proc ignoreError*[Exc](f: Future[void], kind: typedesc[Exc]): Future[void] =
  ## Ignore an error in Future `f` of kind `kind` and transform it into successful completion.
  let completer = newCompleter[void]()

  onSuccessOrError[void](f, onSuccess=(proc() = complete(completer)),
                         onError=proc(t: ref Exception) =
                                if t.getOriginal of Exc: complete(completer)
                                else: completer.completeError(t))

  return completer.getFuture

converter ignoreVoidResult*(f: Future[void]): Future[Bottom] {.deprecated.} =
  ignoreResult(f)

proc thenNowImpl[T, R](f: Future[T], function: (proc(t:T):R)): auto =
  let completer = newCompleter[R]()

  proc onSuccess(t: T) =
    when R is void:
      when T is void:
        function()
      else:
        function(t)
      complete[R](completer)
    else:
      when T is void:
        complete[R](completer, function())
      else:
        complete[R](completer, function(t))

  onSuccessOrError[T](f, onSuccess=onSuccess,
                      onError=proc(t: ref Exception) = completeError[R](completer, t))

  return completer.getFuture

proc completeFrom*[T](c: Completer[T], f: Future[T]) =
  ## When Future `f` completes, complete the Future managed by `c` with the same result.
  doAssert c != nil
  onSuccessOrError[T](f,
                      onSuccess=proc(t: T) =
                        when T is void: complete[T](c)
                        else: complete[T](c, t),
                      onError=proc(t: ref Exception) = completeError[T](c, t))

proc complete*[T](c: Completer[T], f: Future[T]) =
  ## alias for completeFrom
  c.completeFrom(f)

proc thenChainImpl[T, R](f: Future[T], function: (proc(t:T): Future[R])): Future[R] =
  let completer = newCompleter[R]()

  proc thenChainOnSuccess(t: T) =
    when T is void:
      var newFut = function()
    else:
      var newFut = function(t)
    newFut.checkValid
    completeFrom[R](completer, newFut)

  onSuccessOrError[T](f, onSuccess=thenChainOnSuccess,
                      onError=proc(t: ref Exception) = completeError[R](completer, t))

  return completer.getFuture

proc valuetype[T](f: typedesc[Future[T]]): T =
  return now(error(T, "")).value

proc thenWrapper[T, R](f: Future[T], function: (proc(t:T):R)): auto =
  when R is Future:
    when R is Future[void]:
      return thenChainImpl[T, void](f, function)
    else:
      return thenChainImpl[T, type(valuetype(R))](f, function)
  else:
    return thenNowImpl[T, R](f, function)

proc then*[T](f: Future[void], function: (proc(): T)): auto =
  return thenWrapper[void, T](f, function)

proc then*[T](f: Future[T], function: (proc(t:T))): auto =
  return thenWrapper[T, void](f, function)

proc then*(f: Future[void], function: (proc())): auto =
  return thenWrapper[void, void](f, function)

proc then*[T, R](f: Future[T], function: (proc(t:T): R)): auto =
  return thenWrapper[T, R](f, function)

proc ignoreFailCb(t: ref Exception) =
  stderr.writeLine("Error in ignored future")
  t.printError

proc ignore*(f: Future[void]) =
  ## Discard the future result.
  onSuccessOrError(f,
                   proc(t: void) = discard,
                   ignoreFailCb)

proc ignore*[T](f: Future[T]) =
  ## Discard the future result.
  f.onSuccessOrError(nothing1[T], ignoreFailCb)

proc completeError*(self: Completer, x: string) =
  self.completeError(newException(Exception, x))

proc waitForever*(): Future[void] =
  ## Returns a future that never completes.
  let completer = newCompleter[void]()
  GC_ref(completer) # prevent it from being garbage collected
  return completer.getFuture

proc waitForever*[T](t: typedesc[T]): Future[T] =
  ## Returns a future that never completes.
  let completer = newCompleter[T]()
  GC_ref(completer)
  return completer.getFuture

proc `or`*(a: Future[void], b: Future[void]): Future[void] =
  # wait until one of the futures finishes
  let completer = newCompleter[void]()

  a.onSuccessOrError(proc(t: Result[void]) =
                       if not completer.getFuture.isCompleted:
                         completer.complete
                         b.ignore)

  b.onSuccessOrError(proc(t: Result[void]) =
                       if not completer.getFuture.isCompleted:
                         completer.complete
                         a.ignore)

  return completer.getFuture

proc runLoop*[T](f: Future[T]): T =
  ## Run the event loop until Future `f` completes, return the value. If the Future completes with an error, raise it as an exception. Consider using `runMain` instead of this.
  var loopRunning = true

  if not f.isCompleted:
    f.completer.addCallback(proc(data: RootRef, future: Completer[T]) = stopLoop())

  while not f.isCompleted:
    if not loopRunning:
      raise newException(Exception, "loop finished, but future is still uncompleted")
    loopRunning = runLoopOnce()

  f.get

proc waitFor*[T](f: Future[T]): T =
  f.runLoop

proc runMain*(f: Future[void]) =
  ## Run the event loop until Future `f` completes, return the value. If the Future completes with an error, print pretty stack trace and quit.
  try:
    f.runLoop
  except:
    getCurrentException().printError
    quit(1)

proc onErrorQuit*(f: Future[void]) =
  f.onSuccessOrError proc(t: Result[void]) =
    if t.isError:
      t.error.printError
      quit(1)
