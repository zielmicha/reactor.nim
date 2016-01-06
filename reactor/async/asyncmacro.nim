import macros

type
  AsyncIterator* = object
    callback: proc(cont: proc())

proc iterFuture[T](f: Future[T]): AsyncIterator =
  let completer = f.completer
  result.callback = proc(cont: proc()) =
    completer.callback = proc(data: RootRef, future: Completer[T]) =
      cont()

template awaitInIterator*(body: expr): expr =
  let fut = body
  if fut.isCompleted:
    fut.get
  else:
    yield iterFuture(fut)
    fut.get

template await*(body): expr =
  {.error: "await outside of an async proc".}
  discard

proc asyncIteratorRun*(it: (iterator(): AsyncIterator)) =
  var asyncIter = it()
  if finished(it):
    return
  asyncIter.callback(proc() = asyncIteratorRun(it))

macro async*(a): stmt =
  ## `async` macro. Enables you to write asynchronous code in a similar manner to synchrous code.
  ##
  ## For example:
  ## ```
  ## proc add5(s: Future[int]): Future[int] {.async.} =
  ##   asyncReturn((await s) + 5)
  ## ```

  let procName = a[0]
  let pragmas = a[4]
  let body = a[6]
  let returnTypeFull = a[3][0]

  if returnTypeFull.kind != nnkBracketExpr or returnTypeFull[0] != newIdentNode(!"Future"):
    error("invalid return type from async proc (expected Future[T])")

  let returnType = returnTypeFull[1]
  echo returnType.treeRepr

  let asyncHeader = parseStmt("""
template await(e: expr): expr = awaitInIterator(e)
template asyncReturn(e: expr): expr =
  asyncProcCompleter.complete(e)
  return""")

  let asyncFooter = parseStmt("""
asyncIteratorRun(iter)
return asyncProcCompleter.getFuture""")

  let headerNext = parseStmt("let asyncProcCompleter = newCompleter[int]()")[0]
  headerNext[0][2][0][1] = returnType
  asyncHeader.add headerNext

  let asyncBody = parseStmt("""let iter = iterator(): AsyncIterator {.closure.} =
    discard""")[0]

  asyncBody[0][2][6] = body

  asyncHeader.add(asyncBody)
  asyncHeader.add(asyncFooter)

  result = newProc(procName)
  result[3] = a[3]
  result[4] = pragmas
  result[6] = asyncHeader

macro asyncFor*(iterClause: expr, body: expr): stmt =
  ## An asynchronous version of `for` that works on Streams. Example:
  ## ```
  ## proc simplePipe(src: Stream[int], dst: Provider[int]) {.async.} =
  ##   asyncFor item in src:
  ##     echo "piping ", item
  ##     await dst.provide(item)
  ## ```
