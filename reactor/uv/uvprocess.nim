import reactor/uv/uv, reactor/uv/uvutil, reactor/async, posix, strutils, os, tables

type Process* = ref object
  completer: Completer[int]
  options: uv_process_options_t

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

proc startProcess*(command: seq[string],
                   environ: TableRef[string, string]=nil,
                   additionalEnv: openarray[tuple[k: string, v: string]]=[],
                   additionalFiles: openarray[tuple[target: cint, src: cint]]=[]): Process =
  let process = cast[ptr uv_process_t](newUvHandle(UV_PROCESS))

  assert command.len > 0

  result = Process(completer: newCompleter[int]())
  zeroMem(addr result.options, sizeof result.options)
  GC_ref(result)
  process.data = cast[pointer](result)

  proc on_exit(req: ptr uv_process_t, exit_status: int64, term_signal: cint) {.cdecl.} =
    let process = cast[Process](req.data)
    process.completer.complete(exit_status.int)
    GC_unref(process)
    uv_close(req, freeUvMemory)

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

  var maxFd = 0
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

  let res = uv_spawn(getThreadUvLoop(), process, addr result.options)
  if res < 0:
    result.completer.completeError(uvError(res, "spawn " & $command))

proc wait*(process: Process): Future[int] =
  return process.completer.getFuture

proc waitForSuccess*(process: Process): Future[void] =
  process.wait().then(proc(code: int): Future[void] =
                      if code != 0: return immediateError[void]("bad exit code $1 from $2" % [$code, $process.args])
                      else: return immediateFuture())
