import reactor/resolv, reactor/loop, reactor/async, reactor/util, reactor/ipaddress

proc r(addresses: seq[IpAddress]) =
  echo("resolved: ", addresses)

resolveAddress("8.8.8.8").then(r).ignore()
resolveAddress("localhost").then(r).ignore()
resolveAddress("ipv6.google.com").then(r).ignore()

runLoop()
GC_fullCollect()
