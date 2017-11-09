=======
reactor.nim tutorial
=======

reactor.nim is a high-performance asynchronous IO library. It implements `future/promise <https://en.wikipedia.org/wiki/Futures_and_promises>`_ based concurrency. Using reactor.nim you can do file I/O, connect to TCP sockets, spawn processes, make HTTP requests and more.


Basic concepts
===========

- ``Future[T]`` - future represents a value of type ``T`` that will be available in future. In some languages this concept is called a promise ("a promise that a value will be available").

Hello world
===========

.. code-block:: nim
  import reactor

  proc main(): Future[void] =
    return asyncSleep(1000).then(() => "world").then(proc(who: string) = echo "hello " & who)

  when isMainModule:
    # Use runMain to start the event loop
    # Your program will terminate when main() finishes
    main().runMain

``asyncSleep(x: int)`` is a function that returns ``Future[void]`` that completes when ``x`` ms passes. ``then(f: Future[T], p: proc(arg: T): R): Future[R]`` function invokes function ``p`` when future ``f`` completes. The value of ``f`` is passed to the function (in our case, the value is ``void``, so the function doesn't take any arguments).

``runMain`` function takes care of starting event loop and waiting until the program finishes.

.. code-block:: nim
  import reactor

  proc main(): Future[void] {.async.} =
    await asyncSleep(1000)
    let x = "world"
    echo "hello " & x

  when isMainModule: main().runMain

``async`` macro provides much more natural style for writing asynchronous code. You can use ``await`` function to asychronously wait for completion of a future. This way, code looks very similar to a code written in a blocking style, while providing all benefits of asychronous programming.

The following example shows how to do two things concurrently.

.. code-block:: nim
  import reactor

  proc waitForSomethingThatTakesLongTime(): Future[int] {.async.} =
    await asyncSleep(1000)
    return 5

  proc main(): Future[void] {.async.} =
    # Starts two functions concurrently, so they will finish in 1 seconds, not 2 seconds.
    let a = waitForSomethingThatTakesLongTime()
    let b = waitForSomethingThatTakesLongTime()
    # Wait for the results
    echo((await a) + (await b))

  when isMainModule: main().runMain

Hello HTTP
===========

Reactor has support for making HTTP requests.

.. code-block:: nim
  import reactor, reactor/http/httpclient

  proc main() {.async.} =
    # fetch Google page
    let resp = await request(newHttpRequest(httpMethod="GET", url="http://google.com").get)
    # read all data
    let data = await resp.dataInput.readUntilEof()
    echo data

  when isMainModule: main().runMain


Error handling
===========

Life is not a bed of roses and errors happen. When errors happens, the ``runMain`` function will catch it and display nice stack trace that shows what caused the error. The stack trace will correctly show asynchronous calls, as if they were made in synchronous fashion.

.. code-block:: nim
  import reactor

  proc main() {.async.} =
    let sock = await connectTcp("localhost", port=9999)
    echo (await sock.input.read(10))
    sock.close(JustClose)

  when isMainModule: main().runMain

You can make errors yourself using ``error`` constructor or, in ``async`` procs using ``asyncRaise``:

.. code-block:: nim

  proc main(): Future[void] =
    return now(error(void, "error!!!"))

  proc main(): Future[void] {.async.} =
    asyncRaise "error!!!"


Converting callback to Futures
===========

Sometimes have code that uses callbacks you want to convert to Futures. ``Completer[T]`` should be used for this. ``Completer`` represents "other side" of a future - when it is completed, the corresponding future also completes.

.. code-block:: nim

  proc compute(callback: proc(x: int)) =
    # ...
    callback(10)
    # ...

  proc computeAndReturnFuture(): Future[int] =
    let completer = newCompleter[int]()
    compute(proc(x: int) = completer.complete(x))
    return completer.getFuture

Streams
===========

- ``Input[T]`` - a stream of objects of type ``T``. The stream may finish at some point of a time (optionally with an error).
- ``Output[T]`` - a stream that accepts objects of type ``T``. It may be closed.

The most commonly used type of streams are ``ByteInput`` and ``ByteOutput`` (which are aliases to ``Input[byte]`` and ``Output[byte]``). The streams are similar to Go channels and are buffered.

.. code-block:: nim
  import reactor

  proc main() {.async.} =
    # Create a new Input/Output pair. Writes to output will end up in input.
    let (input, output) = newInputOutputPair[int]()
    await output.send(5)
    echo(await input.receive)

    # Close the stream. Instead of JustClose, you can supply any exception.
    await output.sendClose(JustClose)
    # This will raise the "stream closed" (JustClose) exception
    echo(await input.receive)

  when isMainModule: main().runMain()

reactor has a few macros that make working with streams easier.

.. code-block:: nim
  # asynciterator is an asynchronous version of iterator
  proc numbers(): Input[int] {.asynciterator.} =
    var i = 0
    while true:
      asyncYield i
      await asyncSleep(100)
      i += 1

  # asyncFor can be used to iterate over Input[T]
  proc showNumbers() {.async.} =
    asyncFor i in numbers():
      echo "number: ", i

It's possible to send any Nim type over ``Input``/``Output`` pair, but for ``ByteInput``/``ByteOutput`` there are [several helper procs](api/reactor/async/bytes.html) dealing with binary data and text.

``lines`` proc is especially useful for iterating over text files.

.. code-block:: nim
  proc main() {.async.} =
    let conn = connectTcp("atomshare.net", 22)
    asyncFor line in conn.input.lines:
      echo "recv:", line

Another useful proc is `pipe <https://networkos.net/nim/reactor.nim/doc/api/reactor/async/stream.html#pipe,Input[T],Output[T]>`_. It copies all data from ``Input`` to ``Output``. Using it we can easily implement echo server.

.. code-block:: nim
  proc handleConn(conn: BytePipe): Future[void] {.async.} =
    # Pipe data from ``input`` to ``output``.
    pipe(conn.input, conn.output)

  proc main() {.async.} =
    let conns = createTcpServer()
    # conns.incomingConnections has type Input[BytePipe]
    asyncFor conn in conns.incomingConnections:
      # If you have a Future that you want to ignore, don't use ``discard``.
      # Use ``ignore`` instead - it will print warning if Future finished with error
      handleConn(conn).ignore
