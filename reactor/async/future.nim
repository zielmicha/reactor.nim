import reactor/util

const debugFutures = not defined(release)

type Future*[T] = ref object
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
    callback: (proc(data: RootRef, future: Future[T]) {.closure.})

type
  Completer* {.borrow: `.`.}[T] = distinct Future[T]

proc makeInfo[T](c: Future[T]): string =
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
  (Future[T])(c)

proc destroyFuture[T](f: Future[T]) =
  if not f.consumed:
    echo "Destroyed unconsumed future"
    when debugFutures:
      echo f.stackTrace

proc newCompleter*[T](): Completer[T] =
  var fut: Future[T]
  new(fut, destroyFuture[T])
  result = Completer[T](fut)
  result.getFuture.isFinished = false
  when debugFutures:
    result.getFuture.stackTrace = getStackTrace()

proc immediateFuture*[T](value: T): Future[T] =
  let self = newCompleter[T]()
  self.complete(value)
  return self.getFuture

proc immediateError*[T](value: string): Future[T] =
  let self = newCompleter[T]()
  self.completeError(value)
  return self.getFuture

proc complete*[T](self: Completer[T], x: T) =
  let self = self.getFuture
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

proc completeError*[T](self: Completer[T], x: ref Exception) =
  let self = self.getFuture
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
  if f.isFinished:
    f.consumed = true
    if f.isSuccess:
      when T is void:
        onSuccess()
      else:
        onSuccess(f.result)
    else:
      onError(f.error)
  else:
    f.callback =
      proc(data: RootRef, fut: Future[T]) =
        onSuccessOrError[T](f, onSuccess, onError)

proc thenImpl[T, R](f: Future[T], function: (proc(t:T):R)): Future[R] =
  let completer = newCompleter[R]()

  proc onSuccess(t: T) =
    when R is void:
      function(t)
      complete[R](completer)
    else:
      complete[R](completer, function(t))

  onSuccessOrError[T](f, onSuccess=onSuccess,
                      onError=proc(t: ref Exception) = completeError[R](completer, t))

  return completer.getFuture

proc then*[T](f: Future[T], function: (proc(t:T))): Future[void] =
  return thenImpl[T, void](f, function)

proc then*[T, R](f: Future[T], function: (proc(t:T): R)): Future[R] =
  return thenImpl[T, R](f, function)

proc ignore*(f: Future[void]) =
  onSuccessOrError[void](f, proc(t: void) = discard, nothing1[ref Exception])

proc ignore*[T](f: Future[T]) =
  f.onSuccessOrError(nothing1[T], nothing1[ref Exception])

proc completeError*(self: Completer, x: string) =
  self.completeError(newException(Exception, x))

macro async*(a: expr): expr =
  discard
