import reactor/ipaddress
import posix, os
import reactor/uv/uvutil

type
  ifaddrs* {.bycopy, header: "<ifaddrs.h>", importc: "struct ifaddrs".} = object
    ifa_next*: ptr ifaddrs      ##  Next item in list
    ifa_name*: cstring         ##  Name of interface
    ifa_flags*: cuint          ##  Flags from SIOCGIFFLAGS
    ifa_addr*: ptr Sockaddr     ##  Address of interface
    ifa_data*: pointer         ##  Address-specific data

proc getifaddrs(ifap: ptr ptr ifaddrs): cint {.importc, header: "<ifaddrs.h>".}
proc freeifaddrs(ifa: ptr ifaddrs) {.importc, header: "<ifaddrs.h>".}

proc getLocalAddresses*(): seq[tuple[ifaceName: string, address: IpAddress]] =
  result = @[]
  var addrs: ptr ifaddrs
  if getifaddrs(addr addrs) != 0:
    raiseOSError(osLastError())

  defer: freeifaddrs(addrs)

  while addrs != nil:
    if addrs.ifa_addr != nil and addrs.ifa_addr.sa_family in {AF_INET, AF_INET6}:
      let address = sockaddrToIpaddr(addrs.ifa_addr)
      result.add(($addrs.ifa_name, address.ip))
    addrs = addrs.ifa_next
