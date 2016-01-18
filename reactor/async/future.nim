
const debugFutures = not defined(release)

type
  Future*[T] = object
    case isImmediate: bool
    of true:
      value: T
    of false:
      completer: Completer[T]

  Completer*[T] = ref object of RootObj
    when debugFutures:
      stackTrace: string

    case isFinished: bool
    of true:
      consumed: bool
      case isSuccess: bool
      of true:
        result: T
      of false:
        error: ref Exception
    of false:
      data: RootRef
      callback: (proc(data: RootRef, future: Completer[T]) {.closure.})

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
      if c.isSuccess:
        result &= "completed with success"
      else:
        result &= "completed with error"
    else:
      result &= "unfinished"

proc `$`*[T](c: Future[T]): string =
  "Future " & makeInfo(c)

proc `$`*[T](c: Completer[T]): string =
  "Completer " & makeInfo(c.getFuture)

proc getFuture*[T](c: Completer[T]): Future[T] =
  result.isImmediate = false
  result.completer = c

proc destroyCompleter[T](f: Completer[T]) =
  if not f.consumed:
    echo "Destroyed unconsumed future"
    when debugFutures:
      echo f.stackTrace

proc newCompleter*[T](): Completer[T] =
  new(result, destroyCompleter[T])
  result.isFinished = false
  when debugFutures:
    result.stackTrace = getStackTrace()

proc immediateFuture*[T](value: T): Future[T] =
  result.isImmediate = true
  result.value = value

proc immediateFuture*(): Future[void] =
  result.isImmediate = true

proc immediateError*[T](value: string): Future[T] =
  let self = newCompleter[T]()
  self.completeError(value)
  return self.getFuture

proc immediateError*[T](value: ref Exception): Future[T] =
  let self = newCompleter[T]()
  self.completeError(value)
  return self.getFuture

proc isCompleted*(self: Future): bool =
  return self.isImmediate or self.completer.isFinished

proc get*[T](self: Future[T]): T =
  if self.isImmediate:
    when T is not void:
      return self.value
  else:
    assert self.completer.isFinished
    self.completer.consumed = true
    if self.completer.isSuccess:
      when T is not void:
        return self.completer.result
    else:
      raise self.completer.error

proc complete*[T](self: Completer[T], x: T) =
  assert (not self.isFinished)
  let data = self.data
  let callback = self.callback
  self.data = nil
  self.callback = nil
  self.isFinished = true
  self.isSuccess = true
  when T is not void:
    self.result = x
  if callback != nil:
    callback(data, self)

proc complete*(self: Completer[void]) =
  complete[void](self)

proc completeError*[T](self: Completer[T], x: ref Exception) =
  assert (not self.isFinished)
  let data = self.data
  let callback = self.callback
  self.data = nil
  self.callback = nil
  self.isFinished = true
  self.isSuccess = false
  self.error = x
  if callback != nil:
    callback(data, self)

proc onSuccessOrError*[T](f: Future[T], onSuccess: (proc(t:T)), onError: (proc(t:ref Exception))) =
  if f.isImmediate:
    when T is void:
      onSuccess()
    else:
      onSuccess(f.value)
    return
  let c = f.completer
  if c.isFinished:
    c.consumed = true
    if c.isSuccess:
      when T is void:
        onSuccess()
      else:
        onSuccess(c.result)
    else:
      onError(c.error)
  else:
    c.callback =
      proc(data: RootRef, compl: Completer[T]) =
        onSuccessOrError[T](f, onSuccess, onError)

proc onError*(f: Future[Bottom], onError: (proc(t: ref Exception))) =
  onSuccessOrError(f, nil, onError)

proc ignoreResult*[T](f: Future[T]): Future[Bottom] =
  let completer = newCompleter[Bottom]()

  onSuccessOrError[T](f, onSuccess=nothing1[T],
                      onError=proc(t: ref Exception) = completeError(completer, t))

  return completer.getFuture

converter ignoreVoidResult*(f: Future[void]): Future[Bottom] =
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
  onSuccessOrError[T](f,
                      onSuccess=proc(t: T) = complete[T](c, t),
                      onError=proc(t: ref Exception) = completeError[T](c, t))

proc thenChainImpl[T, R](f: Future[T], function: (proc(t:T): Future[R])): Future[R] =
  let completer = newCompleter[R]()

  proc onSuccess(t: T) =
    var newFut = function(t)
    completeFrom[R](completer, newFut)

  onSuccessOrError[T](f, onSuccess=onSuccess,
                      onError=proc(t: ref Exception) = completeError[R](completer, t))

  return completer.getFuture

proc declval[R](r: typedesc[R]): R =
  raise newException(Exception, "executing declval")

proc thenWrapper[T, R](f: Future[T], function: (proc(t:T):R)): auto =
  when R is Future:
    return thenChainImpl[T, type(declval(R).value)](f, function)
  else:
    return thenNowImpl[T, R](f, function)

proc then*[T](f: Future[void], function: (proc(): T)): auto =
  return thenWrapper[void, T](f, function)

proc then*[T](f: Future[T], function: (proc(t:T))): auto =
  return thenWrapper[T, void](f, function)

proc then*[T, R](f: Future[T], function: (proc(t:T): R)): auto =
  return thenWrapper[T, R](f, function)

proc ignoreFailCb(t: ref Exception) =
  echo "Error in ignored future: " & t.msg

proc ignore*(f: Future[void]) =
  onSuccessOrError[void](f,
                         proc(t: void) = discard,
                         ignoreFailCb)

proc ignore*[T](f: Future[T]) =
  f.onSuccessOrError(nothing1[T], ignoreFailCb)

proc completeError*(self: Completer, x: string) =
  self.completeError(newException(Exception, x))

proc runLoop*[T](f: Future[T]): T =
  var loopRunning = true
  while not f.isCompleted:
    if not loopRunning:
      raise newException(Exception, "loop finished, but future is still uncompleted")
    loopRunning = runLoopOnce()

  f.get
