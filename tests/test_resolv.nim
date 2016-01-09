# disabledTEST
discard """resolved: @[8.8.8.8]
resolved: @[0000:0000:0000:0000:0000:0000:0000:0001, 127.0.0.1]
resolved: @[8.8.8.8, 2001:4860:4860:0000:0000:0000:0000:8888]"""

import reactor/resolv, reactor/loop, reactor/async, reactor/util, reactor/ipaddress

proc r(addresses: seq[IpAddress]) =
  echo("resolved: ", addresses)

resolveAddress("8.8.8.8").then(r).ignore()
resolveAddress("localhost").then(r).ignore()
resolveAddress("google-public-dns-a.google.com").then(r).ignore()

GC_fullCollect()
runLoop()
