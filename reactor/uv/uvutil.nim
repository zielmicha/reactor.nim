import reactor/uv/uv, reactor/ipaddress, reactor/ipaddress
import posix

export Sockaddr_storage

type UVError* = object of Exception

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

proc getThreadUvLoop*(): ptr uv_loop_t =
  # TODO: support multithreading
  # for now, check if running on main thread
  if globalLoopId == 0:
    globalLoopId = 1
    threadLoopId = 1
  assert threadLoopId == globalLoopId
  return uv_default_loop()

proc uvError*(code: cint|int, info: string): ref Exception =
  return newException(Exception, info & ": " & $uv_strerror(code.cint))

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
     return (a.sin_addr.s_addr.ipAddress.from4, a.sin_port.int)
  elif address.sa_family == AF_INET6:
    var a = cast[ptr Sockaddr_in6](address)
    return (a.sin6_addr.s6_addr.ipAddress.from6, a.sin6_port.int)
  else:
    raise newException(ValueError, "unknown address family")

proc c_exit(errorcode: cint) {.importc: "exit", header: "<stdlib.h>".}

template uvTopCallback*(c: stmt): stmt {.immediate.} =
  try:
    c
  except:
    echo "Error occured inside the event loop: ", getCurrentExceptionMsg()
    echo getCurrentException().getStackTrace
    c_exit(1)
