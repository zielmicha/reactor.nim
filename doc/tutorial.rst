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
    return asyncSleep(1000).then(() => "world").then(who => echo "hello " & who)

  when isMainModule: main().runMain

``asyncSleep(x: int)`` is a function that returns ``Future[void]`` that completes when a ``x`` ms passes. ``then(f: Future[T], p: proc(arg: T): R): Future[R]`` function invokes function ``p`` when future ``f`` completes. The value of ``f`` is passed to the function (in our case, the value is ``void``, so the function doesn't take any arguments).

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


Hello TCP
===========


Error handling
===========



Streams
===========

- ``Input[T]`` - a stream of objects of type ``T``. The stream may finish at some point of a time (optionally with an error).
- ``Output[T]`` - a stream that accepts objects of type ``T``. It may be closed.

The most commonly used type of streams are ByteInputs and ByteOutputs (which are aliases to ``Input[byte]`` and ``Output[byte]``).


Converting callback to Futures
===========
