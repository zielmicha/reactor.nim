# reactor.nim

![Build status](https://travis-ci.org/zielmicha/reactor.nim.svg)

*reactor.nim* is an asynchronous networking engine for Nim. It's based on libuv and provides future-based API. It's currently in development - more documentetion will be available "soon".

*reactor.nim* doesn't use asynchronous mechanisms from `asyncdispatch` stdlib module and instead provides its own. They are arguably richer and more performant. The API is inspired by Dart and Midori OS (in particular by [the recent article](http://joeduffyblog.com/2015/11/19/asynchronous-everything/)).

There is Emscripten/WebAssembly port planned.
