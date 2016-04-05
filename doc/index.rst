=========
reactor.nim
=========

Introduction
=========

*reactor.nim* is an asynchronous networking engine for Nim. It's based on libuv and provides future-based API.

*reactor.nim* doesn't use asynchronous mechanisms from asyncdispatch stdlib module and instead provides its own. They are arguably richer and more performant. The API is inspired by Dart and Midori OS (in particular by `this article <http://joeduffyblog.com/2015/11/19/asynchronous-everything/>`_).

*reactor.nim* currently works on Linux and Mac OSX. Other platforms supported by libuv and Nim (like Windows) support should be trivial to add - see issue `#3 <https://github.com/zielmicha/reactor.nim/issues/3>`_.

The library is currently in development. You probably shouldn't use it yet for any mission critical applications. The documentation is currently sparse. For now you can look at `tests <https://github.com/zielmicha/reactor.nim/tree/master/tests>`_.

As you are probably going to deal with untrusted data, you should enable range checks even if compiling in release mode - see example `nim.cfg <https://github.com/zielmicha/reactor.nim/blob/master/nim.cfg>`_. *reactor.nim* treats security very seriously.

Modules
=========

*reactor.nim* consists of several modules.

- ``reactor/async`` (API docs: `event <api/reactor/async/event.html>`_, `result <api/reactor/async/result.html>`_, `future <api/reactor/async/future.html>`_, `stream <api/reactor/async/stream.html>`_, `asyncmacro <api/reactor/async/asyncmacro.html>`_, `bytes <api/reactor/async/bytes.html>`_, `asyncutil <api/reactor/async/asyncutil.html>`_)

  This module implements several primitives for writing asynchronous code - in particular futures (also called promises in some languages) and asynchronous streams.

- ``reactor/loop`` (`API docs <api/reactor/loop.html>`_)

  Module implementing the event loop. You will probably only use `runLoop` function from it.

- ``reactor/time`` (`API docs <api/reactor/time.html>`_)

  Sleep asynchronously.

- ``reactor/ipaddress`` (`API docs <api/reactor/ipaddress.html>`_)

  Parse and manipulate IPv4/IPv6 addresses.

- ``reactor/resolv`` (`API docs <api/reactor/resolv.html>`_)

  Resolve hostname into IP addresses.

- ``reactor/tcp`` (`API docs <api/reactor/tcp.html>`_)

  Make TCP connections and listen on TCP sockets.

- ``reactor/udp`` (`API docs <api/reactor/udp.html>`_)

  Send and receive UDP packets.

- ``reactor/tls`` (`API docs <api/reactor/tls.html>`_)

  TLS/SSL support using OpenSSL.

- ``reactor/http/httpclient`` (`API docs <api/reactor/http/httpclient.html>`_)

  HTTP client.

- ``reactor/redis`` (`API docs <api/reactor/redis.html>`_)

  Redis client.

- ``reactor/tun`` (`API docs <api/reactor/tun.html>`_)

  TUN/TAP support (for Linux only).

External libraries
==================

There are libraries that are not part of *reactor.nim*, but are compatible with it:

- `reactorfuse <https://github.com/zielmicha/reactorfuse>`_

  Filesystem in userspace (FUSE).
