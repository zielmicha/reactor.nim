# included from reactor/async.nim
import macros, sequtils

type
  AsyncIterator* = object
    callback: proc(cont: proc())

proc iterFuture[T](f: Future[T]): AsyncIterator =
  let completer = f.completer
  result.callback = proc(cont: proc()) =
    completer.callback = proc(data: RootRef, future: Completer[T]) =
      cont()

template stopAsync*(): typed =
  # we will never be called again
  yield AsyncIterator(callback: nil)

proc callDefers(defers: var seq[proc()]) =
  for i in 0..<defers.len:
    defers[defers.len - i - 1]()

template awaitInIterator*(body: typed, errorFunc: untyped, defers: typed): untyped =
  let fut = body
  when fut is Future:
    assert fut.isImmediate or fut.completer != nil, "nil passed to await"
    if not fut.isCompleted:
      yield iterFuture(fut)
  elif not (fut is Result):
    {.error: "await on wrong type (expected Result or Future)".}

  if not fut.isSuccess:
    let err = attachInstInfo(fut.getResult.error, extInstantiationInfo(-2))
    callDefers(defers)
    errorFunc(err)
    stopAsync()

  when not (fut is Future[void] or fut is Result[void]):
    fut.get
  else:
    fut.get
    discard

template tryAwait*(body: typed): untyped =
  ## Waits for future completion and returns the result.
  let fut = body
  assert fut.isImmediate or fut.completer != nil, "nil passed to await"
  if not fut.isCompleted:
    yield iterFuture(fut)

  fut.getResult

# This collides with threadpool.await (due to compiler bug?)
# template await*(body): expr =
#   {.error: "await outside of an async proc".}
#   discard

proc asyncIteratorRun*(it: (iterator(): AsyncIterator)) =
  var asyncIter = it()
  if finished(it):
    return
  if asyncIter.callback != nil:
    asyncIter.callback(proc() = asyncIteratorRun(it))

proc transformAsyncBody(n: NimNode): NimNode {.compiletime.} =
  if n.kind in RoutineNodes:
    return n

  if n.kind == nnkReturnStmt:
    if n[0].kind == nnkEmpty:
      return newCall(newIdentNode(!"asyncReturn"))
    else:
      return newCall(newIdentNode(!"asyncReturn"), n[0])

  if n.kind == nnkDefer:
    # normal defer appears to work, but is called when iterator yields, not when it exits!
    return newCall(newIdentNode(!"asyncDefer"), n[0])

  let node = n.copyNimTree
  for i in 0..<node.len:
    node[i] = transformAsyncBody(n[i])
  return node

macro async*(a): untyped =
  ## `async` macro. Enables you to write asynchronous code in a similar manner to synchronous code.
  ##
  ## For example:
  ## ```
  ## proc add5(s: Future[int]): Future[int] {.async.} =
  ##   asyncReturn((await s) + 5)
  ## ```

  var a = a
  if a.kind == nnkStmtList:
    if a.len != 1: error("expected exactly one function")
    a = a[0]

  let procName = a[0]
  let allParams = toSeq(a[3].items)
  let params = if allParams.len > 0: allParams[1..<allParams.len] else: @[]
  let pragmas = a[4]
  let body = transformAsyncBody(a[6])
  let returnTypeFull = a[3][0]

  let procNameStripped = if procName.kind == nnkPostfix: procName[1] else: procName
  let procNameStr = newStrLitNode($procNameStripped)

  if returnTypeFull.kind != nnkEmpty and (returnTypeFull.kind != nnkBracketExpr or returnTypeFull[0] != newIdentNode(!"Future")):
    error("invalid return type from async proc (expected Future[T])")

  let returnType = if returnTypeFull.kind == nnkEmpty: newIdentNode(!"void")
                   else: returnTypeFull[1]
  let returnTypeNew = newNimNode(nnkBracketExpr)
  returnTypeNew.add newIdentNode(!"Future")
  returnTypeNew.add returnType

  let completer = parseExpr("newCompleter[int]()")
  completer[0][1] = returnType

  let innerIteratorName = genSym(kind=nskIterator, ident= $procNameStripped)

  var asyncBody = quote do:
    let asyncProcCompleter = `completer`
    var defers: seq[proc()]

    template await(e: typed): untyped =
      awaitInIterator(e, asyncProcCompleter.completeError, defers)

    template asyncRaise(e: typed) =
      callDefers(defers)
      asyncProcCompleter.completeError(attachInstInfo(e, extInstantiationInfo()))
      return

    template asyncDefer(e: typed) =
      if defers == nil: defers = @[]
      defers.add(proc() = e)

    when asyncProcCompleter is Completer[void]:
      template asyncReturn() =
        callDefers(defers)
        asyncProcCompleter.complete()
        return
    else:
      template asyncReturn(e: typed) =
        callDefers(defers)
        asyncProcCompleter.complete(e)
        return

    iterator `innerIteratorName`(): AsyncIterator {.closure.} =
      `body`
      callDefers(defers)
      when `returnType` is void:
        asyncProcCompleter.complete()
      else:
        asyncProcCompleter.completeError(`procNameStr` & ": missing asyncReturn")

    let iter: (iterator(): AsyncIterator) = `innerIteratorName`

    asyncIteratorRun(iter)
    return asyncProcCompleter.getFuture

  result = newNimNode(nnkProcDef, a).add(
    procName,
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode(),
    newEmptyNode())

  result[2] = a[2]
  result[3] = newNimNode(nnkFormalParams)
  result[3].add returnTypeNew
  for param in params:
    result[3].add param
  result[4] = if pragmas.len != 0: pragmas else: newNimNode(nnkEmpty)
  if body.kind != nnkEmpty:
    result[6] = asyncBody

template asyncMain*(body: untyped): untyped =
  proc mainBody() {.async.} =
    body

  mainBody().runMain

macro asyncFor*(iterClause: untyped, body: untyped): untyped =
  ## An asynchronous version of `for` that works on Inputs. Example:
  ## ```
  ## proc simplePipe(src: Input[int], dst: Output[int]) {.async.} =
  ##   asyncFor item in src:
  ##     echo "piping ", item
  ##     await dst.send(item)
  ## ```
  if iterClause.kind != nnkInfix or iterClause[0] != newIdentNode(!"in"):
    error("expected `x in y` after for")

  let coll = iterClause[2]
  let itemName = iterClause[1]

  let newBody = quote do:
    let collection = `coll`
    while true:
      let res = tryAwait receive(collection)
      if not res.isSuccess:
        if res.error.getOriginal of CloseException:
          break
        else:
          asyncRaise(res.error)
      let `itemName` = res.get
      `body`

  newBody

macro asyncIterator*(a): untyped =
  ## An iterator that produces elements asynchronously. Example:
  ## ```
  ## proc intGenerator(): Input[int] {.asyncIterator.} =
  ##   var i = 0;
  ##   while true:
  ##      asyncYield i
  ##      i += 1
  ## ```

  let procName = a[0]
  let allParams = toSeq(a[3].items)
  let params = if allParams.len > 0: allParams[1..<allParams.len] else: @[]
  let pragmas = a[4]
  let body = a[6]
  let returnTypeFull = a[3][0]

  if returnTypeFull.kind != nnkBracketExpr or returnTypeFull[0] != newIdentNode(!"Input"):
    error("invalid return type from async iterator (expected Input[T])")

  let returnType = returnTypeFull[1]
  let ioPair = parseExpr("newInputOutputPair[int](bufferSize=32)")
  ioPair[0][1] = returnType

  var asyncBody = quote do:
    let (asyncStream, asyncProvider) = `ioPair`
    var defers: seq[proc()]

    template await(e: untyped): untyped =
      awaitInIterator(e, asyncProvider.sendClose, defers)

    template asyncRaise(e: untyped): untyped =
      callDefers(defers)
      asyncProvider.sendClose(attachInstInfo(e, extInstantiationInfo()))
      return

    template asyncYield(e: untyped): untyped =
      mixin await
      await asyncProvider.send(e)

    template asyncDefer(e: typed) =
      if defers == nil: defers = @[]
      defers.add(proc() = e)

    let iter = iterator(): AsyncIterator {.closure.} =
      `body`
      asyncRaise(JustClose)

    asyncIteratorRun(iter)
    return asyncStream

  result = newProc(procName)
  result[2] = a[2].copyNimTree # generic params
  result[3] = newNimNode(nnkFormalParams)
  result[3].add returnTypeFull
  for param in params:
    result[3].add param
  result[4] = pragmas
  result[6] = asyncBody
