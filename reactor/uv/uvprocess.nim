import reactor/uv/uv, reactor/uv/uvutil, reactor/file, reactor/async, posix, strutils, os, tables

type Process* = ref object
  files*: seq[BytePipe]
  pid*: int
  completer: Completer[int]
  options: uv_process_options_t
  process: ptr uv_process_t

  args: seq[string]
  argsRaw: seq[pointer]
  environ: seq[string]
  environRaw: seq[pointer]
  stdioContainers: seq[uv_stdio_container_t]

proc makeRawArray(args: var seq[string], start=0): seq[pointer] =
  result = @[]
  for i, arg in args:
    if i < start: continue
    result.add(arg.cstring)
  result.add(nil)

var SOCK_CLOEXEC* {.importc, header: "<sys/socket.h>".}: cint

proc startProcess*(command: seq[string],
                   environ: TableRef[string, string]=nil,
                   additionalEnv: openarray[tuple[k: string, v: string]]=[],
                   additionalFiles: openarray[tuple[target: cint, src: cint]]=[],
                   pipeFiles: openarray[cint]=[],
                   detached=false, uid=0, gid=0): Process =
  ## Start a new process.
  var additionalFiles = @additionalFiles
  # TODO: leak
  let process = cast[ptr uv_process_t](newUvHandle(UV_PROCESS))

  assert command.len > 0

  result = Process(completer: newCompleter[int](), process: process)
  zeroMem(addr result.options, sizeof result.options)
  GC_ref(result)
  process.data = cast[pointer](result)

  proc on_exit(req: ptr uv_process_t, exit_status: int64, term_signal: cint) {.cdecl.} =
    let process = cast[Process](req.data)
    process.completer.complete(exit_status.int)
    GC_unref(process)
    uv_close(cast[ptr uv_handle_t](req), freeUvMemory)

  result.options.exit_cb = on_exit

  result.args = command
  result.argsRaw = makeRawArray(result.args)

  var env: TableRef[string, string]
  env.deepCopy(environ)

  if env == nil:
    env = newTable[string, string]()
    for k, v in envPairs():
      env[k] = v

  for pair in additionalEnv:
    let (k, v) = pair
    env[k] = v

  result.environ = @[]
  for k, v in env.pairs:
    result.environ.add("$1=$2" % [$k, $v])

  result.environRaw = makeRawArray(result.environ)

  result.options.args = cast[cstringArray](addr result.argsRaw[0])
  result.options.file = $(result.args[0])
  result.options.env = cast[cstringArray](addr result.environRaw[0])

  result.stdioContainers = @[]

  result.files = @[]

  var closeFds: seq[cint] = @[]

  defer:
    for fd in closeFds:
      discard close(fd)

  for fd in pipeFiles:
    var pair: array[0..1, cint]
    checkZero "socketpair", socketpair(AF_UNIX, SOCK_STREAM or SOCK_CLOEXEC, 0, pair)
    additionalFiles.add((fd, pair[1]))

    closeFds.add pair[1]
    result.files.add streamFromFd(pair[0])

  var maxFd = 2
  for entry in additionalFiles: maxFd = max(maxFd, entry.target)

  for fd in 0..maxFd:
    var c: uv_stdio_container_t
    if fd <= 2:
      c.flags = UV_INHERIT_FD
      c.data.fd = fd.cint
    else:
      c.flags = UV_IGNORE
    result.stdioContainers.add(c)

  for entry in additionalFiles:
    result.stdioContainers[entry.target].flags = UV_INHERIT_FD
    result.stdioContainers[entry.target].data.fd = entry.src

  result.options.stdio_count = result.stdioContainers.len.cint
  result.options.stdio = addr result.stdioContainers[0]
  result.options.flags = (
    (if detached: cuint(UV_PROCESS_DETACHED) else: 0) or
    (if uid != 0: cuint(UV_PROCESS_SETUID) else: 0) or
    (if gid != 0: cuint(UV_PROCESS_SETGID) else: 0)
  )
  result.options.uid = uid.cuint
  result.options.gid = gid.cuint

  let res = uv_spawn(getThreadUvLoop(), process, addr result.options)
  result.pid = process.pid
  if res < 0:
    result.completer.completeError(uvError(res, "spawn " & $command))

proc wait*(process: Process): Future[int] =
  ## Wait until process returns.
  return process.completer.getFuture

proc kill*(process: Process, signal: int = 15) =
  if uv_process_kill(process.process, signal.cint) < 0:
    raise newException(Exception, "failed to kill process")

proc waitForSuccess*(process: Process): Future[void] =
  ## Wait until process returns. Return error if exit code is other than 0.
  process.wait().then(proc(code: int): Future[void] =
                      if code != 0: return now(error(void, "bad exit code $1 from $2" % [$code, $process.args]))
                      else: return now(just()))

proc detach*(process: Process) =
  # TODO
  discard

# utility functions

proc runProcess*(command: seq[string],
                 environ: TableRef[string, string]=nil,
                 additionalEnv: openarray[tuple[k: string, v: string]]=[],
                 additionalFiles: openarray[tuple[target: cint, src: cint]]=[],
                 pipeFiles: openarray[cint]=[],
                 detached=false, uid=0, gid=0): Future[void] =
  let p = startProcess(
    command = command,
    environ = environ,
    additionalFiles = additionalFiles,
    additionalEnv = additionalEnv,
    pipeFiles = pipeFiles,
    detached = detached, uid = uid, gid = gid)
  return p.waitForSuccess

proc checkOutput*(command: seq[string],
                  environ: TableRef[string, string]=nil,
                  additionalEnv: seq[tuple[k: string, v: string]] = @[]): Future[string] {.async.} =
  let p =
    startProcess(command=command, environ = environ, additionalEnv = additionalEnv, pipeFiles = @[4.cint])

  let reader = p.files[0].input.readUntilEof
  await p.waitForSuccess
  return reader
