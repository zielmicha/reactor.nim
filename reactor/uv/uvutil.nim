import reactor/uv/uv, reactor/ipaddress, reactor/ipaddress
import os

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

proc newUvReq*(`type`: uv_req_type): pointer =
  return allocShared0(uv_req_size(`type`))

proc newUvHandle*(`type`: uv_handle_type): pointer =
  return allocShared0(uv_handle_size(`type`))

proc freeUv*(t: ptr) =
  freeShared(t)

proc freeUvMemory*(t: ptr uv_handle_t) {.cdecl.} =
  freeUv(t)

var threadLoopId  {.threadvar.}: int
var globalLoopId: int

proc init() =
  when not defined(windows):
    signal(SIGPIPE, SIG_IGN)

proc getThreadUvLoop*(): ptr uv_loop_t =
  # TODO: support multithreading
  # for now, check if running on main thread
  if globalLoopId == 0:
    init()
    globalLoopId = 1
    threadLoopId = 1
  assert threadLoopId == globalLoopId
  return uv_default_loop()

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
     return (a.sin_addr.s_addr.ipAddress.from4, a.sin_port.int) # FIXME: htons?
  elif address.sa_family == AF_INET6:
    var a = cast[ptr Sockaddr_in6](address)
    let address = a.sin6_addr.s6_addr.ipAddress.from6
    return (address, htons(a.sin6_port).int)
  else:
    raise newException(ValueError, "unknown address family")

proc c_exit(errorcode: cint) {.importc: "exit", header: "<stdlib.h>".}

template uvTopCallback*(c: untyped): untyped =
  try:
    c
  except:
    echo "Error occured inside the event loop: ", getCurrentExceptionMsg()
    echo getCurrentException().getStackTrace
    c_exit(1)
