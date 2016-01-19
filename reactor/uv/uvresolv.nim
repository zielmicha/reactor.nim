import reactor/ipaddress
import reactor/async
import reactor/uv/uv, reactor/uv/uvutil
import posix

proc addressesFromInfo(res: ptr AddrInfo): seq[IpAddress] =
  var res = res
  result = @[]
  while res != nil:
    # getaddrinfo returns duplicate results for multiple socktypes
    if res.ai_socktype == SOCK_DGRAM:
      if res.ai_family == AF_INET:
        result.add cast[ptr Sockaddr_in](res.ai_addr).sin_addr.s_addr.ipAddress
      elif res.ai_family == AF_INET6:
        result.add cast[ptr Sockaddr_in6](res.ai_addr).sin6_addr.s6_addr.ipAddress

    res = res.ai_next

  uv_freeaddrinfo(res)

proc resolveAddress*(hostname: string): Future[seq[IpAddress]] =
  let request = cast[ptr uv_getaddrinfo_t](newUvReq(UV_GETADDRINFO))

  type State = ref object
    completer: Completer[seq[IpAddress]]
    hostname: string

  let state = State(completer: newCompleter[seq[IpAddress]]())
  state.hostname = hostname

  GC_ref(state)
  request.data = cast[pointer](state)

  proc callbackWrapper(req: ptr uv_getaddrinfo_t, status: cint, res: ptr AddrInfo) {.cdecl.} =
    uvTopCallback:
      let state = cast[State](req.data)

      if status == 0:
        let addresses = addressesFromInfo(res)
        state.completer.complete(addresses)
      else:
        state.completer.completeError("name resolution failed")

      uv_freeaddrinfo(res)
      GC_unref(state)

  let err = uv_getaddrinfo(getThreadUvLoop(), request, callbackWrapper, state.hostname, nil, nil)
  if err != 0:
    return immediateError[seq[IpAddress]]("name resolution failed")

  return state.completer.getFuture
