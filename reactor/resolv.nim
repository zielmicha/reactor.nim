include reactor/uv/uvresolv

proc resolveSingleAddress*(host: string): Future[IpAddress] {.async.} =
  let addresses = await resolveAddress(host)
  if addresses.len == 0:
    asyncRaise "no address resolved"
  else:
    return addresses[0]
