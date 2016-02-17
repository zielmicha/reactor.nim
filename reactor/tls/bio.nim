import reactor/async, reactor/tls/opensslwrapper

proc bCreate(bio: BIO): cint {.cdecl.} =
  bio.shutdown = 1
  bio.init = 1
  bio.num = -1
  bio.`ptr` = nil
  return 1

proc getPipe(bio: BIO): BytePipe =
  return cast[BytePipe](bio.`ptr`)

proc bDestroy(bio: BIO): cint {.cdecl.} =
  if bio.`ptr` != nil:
    GC_unref(bio.getPipe)
    bio.`ptr` = nil

proc clearRetryFlags(bio: BIO) =
  BIO_clear_flags(bio, (BIO_FLAGS_READ or BIO_FLAGS_WRITE or BIO_FLAGS_IO_SPECIAL or BIO_FLAGS_SHOULD_RETRY).cint)

proc setRetryRead(bio: BIO) =
  BIO_set_flags(bio, (BIO_FLAGS_READ or BIO_FLAGS_SHOULD_RETRY).cint)

proc setRetryWrite(bio: BIO) =
  BIO_set_flags(bio, (BIO_FLAGS_WRITE or BIO_FLAGS_SHOULD_RETRY).cint)

proc bRead(bio: BIO; buf: cstring; num: cint): cint {.cdecl.} =
  clearRetryFlags(bio)
  let input = bio.getPipe.input
  let view = input.peekMany()
  assert num >= 0
  let doRead = min(view.len, num.int)
  if doRead == 0:
    setRetryRead(bio)
    return -1
  else:
    view.slice(0, doRead).copyTo(addrView(buf, num))
    input.discardItems(doRead)
    return doRead.cint

proc bWrite(bio: BIO; buf: cstring; num: cint): cint {.cdecl.} =
  clearRetryFlags(bio)
  let output = bio.getPipe.output
  if output.freeBufferSize < num:
    setRetryWrite(bio)
    return cint(-1)

  let didWrite = output.provideSome(addrView(buf, num))
  assert didWrite == num

  return didWrite.cint

proc bPuts(bio: BIO, buf: cstring): cint {.cdecl.} =
  doAssert(false)

proc bGets(bio: BIO, buf: cstring, num: cint): cint {.cdecl.} =
  doAssert(false)

proc bCtrl(bio: BIO, cmd: cint, arg1: clong, arg2: pointer): clong {.cdecl.} =
  if cmd == BIO_CTRL_FLUSH:
    return 1
  return 0

var
  pipeBioMethod = BIO_METHOD(
    `type`: 0.cint,
    name: "pipe bio",
    bwrite: bWrite,
    bread: bRead,
    bputs: bPuts,
    bgets: bGets,
    ctrl: bCtrl,
    create: bCreate,
    destroy: bDestroy,
    callback_ctrl: nil
  )

proc wrapBio*(pipe: BytePipe): BIO =
  let b = BIO_new(addr pipeBioMethod)
  GC_ref(pipe)
  b.`ptr` = cast[pointer](pipe)
  return b
