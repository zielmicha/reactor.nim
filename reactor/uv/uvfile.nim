import reactor/util, reactor/async, reactor/uv/uv, reactor/uv/uvutil
import posix

proc makeReq(callback: proc(req: ptr uv_fs_t)): tuple[req: ptr uv_fs_t, cb: uv_fs_cb] =
  type State = ref object
    callback: proc(req: ptr uv_fs_t)

  let state = new(State)
  state.callback = callback
  let req = cast[ptr uv_fs_t](newUvReq(UV_FS))
  GC_ref(state)
  req.data = cast[pointer](state)

  proc cb(req: ptr uv_fs_t) {.cdecl.} =
    let state = cast[State](req.data)
    state.callback(req)
    freeUv(req)
    GC_unref(state)

  return (req, cb)

type
  FileFlags = distinct cint

  FileFd* = distinct int

let
  Rewrite* = FileFlags(O_TRUNC or O_WRONLY)
  Append* = FileFlags(O_APPEND or O_WRONLY)
  ReadOnly* = FileFlags(O_RDONLY)
  ReadWrite* = FileFlags(O_RDWR)

proc open*(path: string, flags: FileFlags, mode: cint=0o600): Future[FileFd] =
  let completer = newCompleter[FileFd]()

  proc callback(req: ptr uv_fs_t) =
    if req.result < 0:
      completer.completeError(uvError(req.result, "open"))
    else:
      completer.complete(req.result.FileFd)

  let (req, cb) = makeReq(callback)
  let res = uv_fs_open(getThreadUvLoop(), req, path, flags.cint, mode, cb)
  if res < 0:
    completer.completeError(uvError(res, "open"))

  return completer.getFuture()
