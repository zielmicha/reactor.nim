# reactor.nim

[![Build Status](https://dev.azure.com/michal0421/michal/_apis/build/status/zielmicha.reactor.nim?branchName=master)](https://dev.azure.com/michal0421/michal/_build/latest?definitionId=1?branchName=master)

*reactor.nim* is an asynchronous networking engine for Nim. It's based on libuv and provides future-based API. For more, see [documentation](https://networkos.net/nim/reactor.nim/doc/).

*reactor.nim* doesn't use asynchronous mechanisms from `asyncdispatch` stdlib module and instead provides its own. They are arguably richer and more performant. The API is inspired by Dart and Midori OS (in particular by [this article](http://joeduffyblog.com/2015/11/19/asynchronous-everything/)).

There is Emscripten/WebAssembly port planned.

You can discuss reactor.nim on [Freenode #reactor.nim](https://webchat.freenode.net/?channels=reactor.nim).

## FAQ

### Where is the documentation?

* [API documentation](https://networkos.net/nim/reactor.nim/doc/)
* [Tutorial](https://networkos.net/nim/reactor.nim/doc/tutorial.html)

### How do I report security bugs?

Please email michal@zielinscy.org.pl.

## Which platforms are supported?

reactor.nim works on Linux and Mac OSX. Windows support should be trivial to add - see #3.
