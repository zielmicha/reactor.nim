import strutils, sequtils, future, hashes
import collections/bytes, collections/iterate

type
  Interface[T] = tuple[address: T, mask: int]

  Ip6Address* = distinct array[16, uint8]
  Ip6Interface* = Interface[Ip6Interface]

  Ip4Address* = distinct array[4, uint8]
  Ip4Interface* = Interface[Ip4Interface]

  IpKind* = enum
    ip4, ip6

  IpAddress* = object
    ## Represents IPv4 or IPv6 address.
    case kind*: IpKind
    of ip4:
      ip4*: Ip4Address
    of ip6:
      ip6*: Ip6Address

  IpInterface* = Interface[IpAddress]
    ## Represents IP address with a mask.

proc toBinaryString*(s: Ip4Address | Ip6Address): string =
  ## Converts IP address to its binary representation.
  const size = when s is Ip4Address: 4 else: 16
  result = newString(size)
  copyMem(result.cstring, unsafeAddr(s), size)

proc toBinaryString*(s: IpAddress): string =
  ## Converts IP address to its binary representation.
  case s.kind:
    of ip4:
      return s.ip4.toBinaryString
    of ip6:
      return s.ip6.toBinaryString

proc ipAddress*(a: int32): Ip4Address =
  ## Creates IPv4 address from 32-bit integer.
  copyMem(addr result, a.unsafeAddr, 4)

proc ipAddress*(a: uint32): Ip4Address =
  ## Creates IPv4 address from 32-bit integer.
  copyMem(addr result, a.unsafeAddr, 4)

proc ipAddress*(a: array[16, char]): Ip6Address =
  ## Creates IPv6 address from its binary representation.
  var a = a
  copyMem(addr result, addr a, 16)

proc ipAddress*(a: array[16, byte]): Ip6Address =
  ## Creates IPv6 address from its binary representation.
  var a = a
  copyMem(addr result, addr a, 16)

proc ipAddress*(a: array[4, char]): Ip4Address =
  ## Creates IPv4 address from its binary representation.
  var a = a
  copyMem(addr result, addr a, 4)

proc ipAddress*(a: array[4, byte]): Ip4Address =
  ## Creates IPv4 address from its binary representation.
  var a = a
  copyMem(addr result, addr a, 4)

converter from4*(a: Ip4Address): IpAddress =
  result.kind = ip4
  result.ip4 = a

converter from6*(a: Ip6Address): IpAddress =
  result.kind = ip6
  result.ip6 = a

proc ipFromBinaryString*(s: string): IpAddress =
  if s.len == 4:
    return byteArray(s, 4).Ip4Address
  elif s.len == 16:
    return byteArray(s, 16).Ip6Address
  else:
    raise newException(ValueError, "bad binary IP length")

proc `[]`*(a: Ip4Address, index: int): uint8 = array[4, uint8](a)[index]
proc `[]`*(a: Ip6Address, index: int): uint8 = array[16, uint8](a)[index]
proc `[]`*(a: IpAddress, k: int): uint8 =
  ## Returns `k`-th byte of the IP address.
  case a.kind:
  of ip4: return a.ip4[k]
  of ip6: return a.ip6[k]

proc `$`*(a: Ip4Address): string =
  "$1.$2.$3.$4" % [$a[0], $a[1], $a[2], $a[3]]

proc toCanonicalString(a: Ip6Address): string =
  ## Converts IPv6 to canonical text representation.
  ## See: https://tools.ietf.org/html/rfc5952#section-4
  var groups: seq[string] = @[]
  for i in 0..7:
    var group = a[2*i].int.toHex(2) & a[2*i+1].int.toHex(2)
    group = group.strip(trailing=false, leading=true, chars={'0'}).toLowerAscii
    if group == "": group = "0"
    groups.add(group)

  var zeroRuns: seq[int] = @[]
  for i in 0..7:
    var runLength = 0
    for j in i..7:
      if groups[j] != "0": break
      runLength += 1
    zeroRuns.add(runLength)

  let maxRun = argmax(zeroRuns)

  if zeroRuns[maxRun] == 8:
    return "::"

  if zeroRuns[maxRun] > 1:
    groups = groups[0..<maxRun] & @[""] & groups[maxRun + zeroRuns[maxRun]..^1]

  result = groups.join(":")

  if result.startswith(":"):
    result = ":" & result
  if result.endswith(":"):
    result = result & ":"

proc `$`*(a: Ip6Address): string =
  a.toCanonicalString

proc `$`*(a: IpAddress): string =
  case a.kind:
  of ip4: return $a.ip4
  of ip6: return $a.ip6
  else: doAssert(false)

proc `$`*[T](a: Interface[T]): string =
  "$1/$2" % [$a.address, $a.mask]

proc addressBitLength*(kind: IpKind): int =
  case kind:
  of ip4: return 32
  of ip6: return 128

proc addressBitLength*(a: IpAddress): int =
  a.kind.addressBitLength

proc addressBitLength*(a: Ip4Address): int = addressBitLength(ip4)

proc addressBitLength*(a: Ip6Address): int = addressBitLength(ip6)

proc parseAddress4*(a: string): Ip4Address =
  let parts = a.split(".").map(a => parseInt(a).uint8).toSeq
  if parts.len != 4:
    raise newException(ValueError, "invalid IPv4 address ($1)" % [$a])
  [parts[0], parts[1], parts[2], parts[3]].Ip4Address

proc parseAddress6*(s: string): Ip6Address =
  var parts = s.split(":")
  if len(parts) < 8:
    let emptyPart = parts.find("")
    if emptyPart == -1:
      raise newException(ValueError, "invalid IPv6 address ($1)" % [$s])
    var newParts = parts[0..<emptyPart]
    for i in 0..(8 - len(parts)):
      newParts.add "0"
    newParts &= parts[emptyPart+1..^1]
    parts = newParts

  if len(parts) != 8:
    raise newException(ValueError, "invalid IPv6 address ($1)" % [$s])

  var address: array[16, uint8]
  for i, part in parts:
    let num = parseHexInt(part)
    if num > 0xffff or num < 0:
      raise newException(ValueError, "invalid IPv6 address ($1)" % [$s])
    address[i*2] = uint8(num div 256)
    address[i*2+1] = uint8(num mod 256)

  address.Ip6Address

proc parseAddress*(a: string): IpAddress =
  assert a != nil
  if ":" in a:
    result.kind = ip6
    result.ip6 = parseAddress6(a)
  else:
    result.kind = ip4
    result.ip4 = parseAddress4(a)

proc getBit*(a: Ip4Address | Ip6Address | IpAddress, i: int): bool =
  return ((a[i div 8] shr uint8(i mod 8)) and 1) == 1

proc asMask*(s: Ip4Address | Ip6Address | IpAddress): int =
  let S = s.addressBitLength
  var mask = 0
  for i in 0..<S:
    if not s.getBit(i):
      break
    mask += 1
  for i in mask..<S:
    if s.getBit(i):
      raise newException(ValueError, "%1 is not valid mask address" % [$s])
  return mask

proc parseInterface*(a: string): IpInterface =
  let splt = a.split("/")
  let address = splt[0].parseAddress
  var length: int
  if splt.len == 1:
    length = address.kind.addressBitLength
  elif splt.len == 2:
    length = parseInt(splt[1])
  else:
    raise newException(ValueError, "invalid interface address")

  if length < 0 or length > address.kind.addressBitLength:
    raise newException(ValueError, "invalid interface mask")

  return (address: address, mask: length)

proc makeMaskAddress4*(mask: int): Ip4Address =
  var arr: array[4, uint8]
  var mask = mask
  var index = 0
  while mask > 8:
    arr[index] = 0xFF
    mask -= 8
    index += 1
  arr[index] = uint8(0xff xor ((1 shr (8 - mask)) - 1))
  return arr.Ip4Address

proc `==`*(a: Ip4Address, b: Ip4Address): bool =
  return (array[4, uint8])(a) == (array[4, uint8])(b)

proc `==`*(a: Ip6Address, b: Ip6Address): bool =
  return (array[16, uint8])(a) == (array[16, uint8])(b)

proc `==`*(a: IpAddress, b: IpAddress): bool =
  if a.kind != b.kind:
    return
  case a.kind:
    of ip4:
      return a.ip4 == b.ip4
    of ip6:
      return a.ip6 == b.ip6

proc contains*[T: Ip4Address | Ip6Address](s: Interface[T], ip: T): bool =
  for i in 0..<s.mask:
    if s.address.getBit(i) != ip.getBit(i):
      return false
  return true

proc contains*(s: IpInterface, i: IpAddress): bool =
  if s.address.kind != i.kind:
    return false

  case s.address.kind:
    of ip4:
      return contains((s.address.ip4, s.mask), i.ip4)
    of ip6:
      return contains((s.address.ip6, s.mask), i.ip6)

proc networkAddress*(i: IpInterface): IpAddress =
  template compute(address, length) =
    var target = array[length, uint8](address)

    for j in 0..<length:
      let tmask = 8 - min(max(i.mask - j * 8, 0), 8)
      target[j] = target[j] and uint8(not ((1 shl tmask) - 1))

    return target.ipAddress

  case i.address.kind:
    of ip4:
      compute(i.address.ip4, 4)
    of ip6:
      compute(i.address.ip6, 16)

proc `+`*(i: IpAddress, k: int64): IpAddress =
  var k = k
  template compute(address, length) =
    var target = array[length, uint8](address)
    var sign = if k >= 0: 1 else: -1
    k = abs(k)
    var overflow = 0
    for jj in 0..<length:
      let j = length - jj - 1
      let val = target[j].int + (k and 0xFF) * sign + overflow
      target[j] = val and 0xFF
      overflow = val shr 8
      k = k shr 8

    if k > 0 or overflow > 0:
      raise newException(ValueError, "IP address range exceeded")

    return target.ipAddress

  case i.kind:
    of ip4:
      compute(i.ip4, 4)
    of ip6:
      compute(i.ip6, 16)

proc nthAddress*(i: IpInterface, n: int64): IpAddress =
  if n < 0 or (i.mask < 63 and (1 shl i.mask) <= n):
    raise newException(ValueError, "address out of network range")

  return i.networkAddress + n

proc hash*(x: IpAddress): int =
  result = 0
  case x.kind:
    of ip4:
      return (array[4, uint8](x.ip4)).hash
    of ip6:
      return (array[16, uint8](x.ip6)).hash

when isMainModule:
  assert parseAddress("127.0.0.1") == [127'u8, 0'u8, 0'u8, 1'u8].Ip4Address
  assert parseAddress("::1") == [0'u8, 0'u8, 0'u8, 0'u8,
                                 0'u8, 0'u8, 0'u8, 0'u8,
                                 0'u8, 0'u8, 0'u8, 0'u8,
                                 0'u8, 0'u8, 0'u8, 1'u8].Ip6Address
  assert parseAddress("::") == [0'u8, 0'u8, 0'u8, 0'u8,
                                0'u8, 0'u8, 0'u8, 0'u8,
                                0'u8, 0'u8, 0'u8, 0'u8,
                                0'u8, 0'u8, 0'u8, 0'u8].Ip6Address
  assert parseAddress("123:4555::54:65") == [0x1'u8, 0x23'u8, 0x45'u8, 0x55'u8,
                                             0'u8, 0'u8, 0'u8, 0'u8,
                                             0'u8, 0'u8, 0'u8, 0'u8,
                                             0'u8, 0x54'u8, 0'u8, 0x65'u8].Ip6Address
  echo parseAddress("0123:4567:89ab:cdef:0123:4567:89ab:cdef")

  assert($parseAddress("::") == "::")
  assert($parseAddress("::1") == "::1")
  assert($parseAddress("1::") == "1::")
  assert($parseAddress("1::1") == "1::1")
  assert($parseAddress("2001:db8::1") == "2001:db8::1")
  assert($parseAddress("2001:db8:0:0:0:0:2:1") == "2001:db8::2:1")
  assert($parseAddress("2001:db8:0:1:1:1:1:1") == "2001:db8:0:1:1:1:1:1")

  assert(networkAddress((parseAddress("255.255.255.255"), 9)) == parseAddress("255.128.0.0"))
  assert(networkAddress((parseAddress("10.66.77.22"), 24)) == parseAddress("10.66.77.0"))

  assert(parseAddress("10.66.77.22") + 1 == parseAddress("10.66.77.23"))
  assert(parseAddress("10.66.77.22") + 257 == parseAddress("10.66.78.23"))
  assert(parseAddress("10.66.77.22") + 256*256 == parseAddress("10.67.77.22"))
  assert(parseAddress("10.66.77.22") + 256*256*256*10 == parseAddress("20.66.77.22"))
