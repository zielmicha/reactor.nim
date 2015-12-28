import os

const uvPath = splitPath(currentSourcePath()).head & "/../../deps/libuv/"

{.passc: "-I" & uvPath & "include".}
{.passc: "-I" & uvPath & "src".}

{.compile: uvPath & "src/fs-poll.c"}
{.compile: uvPath & "src/inet.c"}
{.compile: uvPath & "src/threadpool.c"}
{.compile: uvPath & "src/uv-common.c"}
{.compile: uvPath & "src/version.c"}

when defined(macosx) or defined(linux):
  {.passc: "-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64".}
  {.compile: uvPath & "src/unix/async.c".}
  {.compile: uvPath & "src/unix/core.c".}
  {.compile: uvPath & "src/unix/dl.c".}
  {.compile: uvPath & "src/unix/fs.c".}
  {.compile: uvPath & "src/unix/getaddrinfo.c".}
  {.compile: uvPath & "src/unix/getnameinfo.c".}
  {.compile: uvPath & "src/unix/loop.c".}
  {.compile: uvPath & "src/unix/loop-watcher.c".}
  {.compile: uvPath & "src/unix/pipe.c".}
  {.compile: uvPath & "src/unix/poll.c".}
  {.compile: uvPath & "src/unix/process.c".}
  {.compile: uvPath & "src/unix/signal.c".}
  {.compile: uvPath & "src/unix/stream.c".}
  {.compile: uvPath & "src/unix/tcp.c".}
  {.compile: uvPath & "src/unix/thread.c".}
  {.compile: uvPath & "src/unix/timer.c".}
  {.compile: uvPath & "src/unix/tty.c".}
  {.compile: uvPath & "src/unix/udp.c".}

when defined(linux):
  {.compile: uvPath & "src/unix/linux-core.c"}
  {.compile: uvPath & "src/unix/linux-inotify.c"}
  {.compile: uvPath & "src/unix/linux-syscalls.c"}

when defined(macosx):
  {.passc: "-D_DARWIN_USE_64_BIT_INODE=1".}
  {.compile: uvPath & "src/unix/kqueue.c"}
  {.compile: uvPath & "src/unix/darwin.c".}
  {.compile: uvPath & "src/unix/fsevents.c".}
  {.compile: uvPath & "src/unix/darwin-proctitle.c".}

when defined(windows):
  {.compile: uvPath & "src/win/async.c".}
  {.compile: uvPath & "src/win/core.c".}
  {.compile: uvPath & "src/win/dl.c".}
  {.compile: uvPath & "src/win/error.c".}
  {.compile: uvPath & "src/win/fs.c".}
  {.compile: uvPath & "src/win/fs-event.c".}
  {.compile: uvPath & "src/win/getaddrinfo.c".}
  {.compile: uvPath & "src/win/getnameinfo.c".}
  {.compile: uvPath & "src/win/handle.c".}
  {.compile: uvPath & "src/win/loop-watcher.c".}
  {.compile: uvPath & "src/win/pipe.c".}
  {.compile: uvPath & "src/win/thread.c".}
  {.compile: uvPath & "src/win/poll.c".}
  {.compile: uvPath & "src/win/process.c".}
  {.compile: uvPath & "src/win/process-stdio.c".}
  {.compile: uvPath & "src/win/req.c".}
  {.compile: uvPath & "src/win/signal.c".}
  {.compile: uvPath & "src/win/stream.c".}
  {.compile: uvPath & "src/win/tcp.c".}
  {.compile: uvPath & "src/win/tty.c".}
  {.compile: uvPath & "src/win/timer.c".}
  {.compile: uvPath & "src/win/udp.c".}
  {.compile: uvPath & "src/win/util.c".}
  {.compile: uvPath & "src/win/winapi.c".}
  {.compile: uvPath & "src/win/winsock.c".}
