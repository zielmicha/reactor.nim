import reactor/uv/uv, reactor/ipaddress, reactor/ipaddress, reactor/uv/uvsizeof
import os, posix

type UVError* = object of Exception

when not compileOption("threads"):
  {.error: "Please compile with --threads:on (libuv requires pthreads even if you don't use threads)".}

when defined(windows):
  import winlean
else:
  import posix

template checkZero*(name, e) =
  if e != 0:
    raise newException(UVError, "call to " & name & " failed")

proc calloc(o: csize, a: csize): pointer {.importc, header: "<string.h>".}
proc free(a: pointer) {.importc, header: "<string.h>".}

proc allocUv*(a: int): pointer =
  result = calloc(1, a.csize)

proc freeUv*(t: pointer) =
  free(t)

#

proc newUvReq*(`type`: uv_req_type): pointer =
  return allocUv(uv_req_size(`type`))

proc newUvHandle*(`type`: uv_handle_type): pointer =
  return allocUv(uv_handle_size(`type`))

proc freeUvMemory*(t: ptr uv_handle_t) {.cdecl.} =
  freeUv(t)

var threadLoop {.threadvar.}: ptr uv_loop_t

proc init() =
  threadLoop = uv_default_loop()
  when not defined(windows):
    discard sigignore(SIGPIPE)

when not defined(enableMtcp):
  init()

when defined(enableMtcp):
  proc uv_loop_init_mtcp(loop: ptr uv_loop_t, core: cint): cint {.importc.}

  proc initThreadLoopMtcpImpl*(core: int) =
    threadLoop = cast[ptr uv_loop_t](allocShared0(sizeofLoop()))
    if uv_loop_init_mtcp(threadLoop, core.cint) != 0:
      raise newException(Exception, "couldn't create MTCP loop")

proc initThreadLoopImpl*() =
  assert threadLoop == nil
  threadLoop = cast[ptr uv_loop_t](allocShared0(sizeofLoop()))
  if uv_loop_init(threadLoop) != 0:
    raise newException(Exception, "couldn't create loop")

proc destroyThreadLoopImpl*() =
  if uv_loop_close(threadLoop) != 0:
    raise newException(Exception, "couldn't destroy thread loop (has it processed all events?)")
  freeShared(threadLoop)
  threadLoop = nil

proc getThreadUvLoop*(): ptr uv_loop_t =
  if threadLoop == nil:
    raise newException(Exception, "Thread loop is not initialized. Use initThreadLoop() and destroyThreadLoop()")
  return threadLoop

proc uvError*(code: cint|int, info: string): ref Exception =
  return newException(Exception, info & ": " & $uv_strerror(code.cint))

proc osError*(info: string): ref Exception =
  let code = osLastError()
  return newException(Exception, info & ": " & osErrorMsg(code))

when defined(windows):
  proc htons(a: uint16): uint16 =
    # windows is always low endian
    return (((a and 0xFF) shl 8) or ((a shr 8) and 0xFF)).uint16

  type InPort = uint16

  template s6addr*(a): untyped =
    a.bytes

when not compiles(htons(cast[InPort](0))):
  # Nim >0.13.0 compat
  proc htons(port: InPort): InPort =
    return cast[InPort](htons(cast[int16](port)))

proc ipaddrToSockaddr*(address: ptr SockAddr, ip: IpAddress, port: int) =
  var ip = ip
  case ip.kind:
  of ip4:
    let addr4 = cast[ptr SockAddr_in](address)
    addr4.sin_family = AF_INET
    addr4.sin_port = htons(cast[InPort](port.uint16))
    copyMem(addr4.sin_addr.s_addr.addr, addr ip.ip4, 4)
  of ip6:
    let addr6 = cast[ptr SockAddr_in6](address)
    addr6.sin6_family = AF_INET6
    addr6.sin6_port = htons(cast[InPort](port.uint16))
    copyMem(addr6.sin6_addr.s6_addr.addr, addr ip.ip6, 16)

proc sockaddrToIpaddr*(address: ptr SockAddr): tuple[address: IpAddress, port: int] =
  if address.sa_family == AF_INET:
     var a = cast[ptr Sockaddr_in](address)
     return (a.sin_addr.s_addr.ipAddress.from4, htons(a.sin_port).int)
  elif address.sa_family == AF_INET6:
    var a = cast[ptr Sockaddr_in6](address)
    let address = a.sin6_addr.s6_addr.ipAddress.from6
    return (address, htons(a.sin6_port).int)
  else:
    raise newException(ValueError, "unknown address family")

var FD_CLOEXEC* {.importc, header: "<fcntl.h>"}: cint

proc setCloexec*(fd: cint, state: cint=1): cint {.importc: "uv__cloexec_fcntl", discardable.}
proc dupCloexec*(fd: cint): cint {.importc: "uv__dup".}

proc c_exit(errorcode: cint) {.importc: "exit", header: "<stdlib.h>".}

template uvTopCallback*(c: untyped): untyped =
  try:
    c
  except:
    echo "Error occured inside the event loop: ", getCurrentExceptionMsg()
    echo getCurrentException().getStackTrace
    c_exit(1)
