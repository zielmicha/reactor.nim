import strutils, sequtils, future

type
  Interface*[T] = tuple[address: T, mask: int]

  Ip6Address* = distinct array[16, uint8]
  Ip6Interface* = Interface[Ip6Interface]

  Ip4Address* = distinct array[4, uint8]
  Ip4Interface* = Interface[Ip4Interface]

  IpKind* = enum
    ip4, ip6

  IpAddress* = object
    case kind*: IpKind
    of ip4:
      ip4*: Ip4Address
    of ip6:
      ip6*: Ip6Address

  IpInterface* = Interface[IpAddress]

proc toBinaryString*(s: Ip4Address | Ip6Address): string =
  const size = s.high - s.low + 1
  result = newString(size)
  copyMem(result.cstring, unsafeAddr(s), size)

proc toBinaryString*(s: IpAddress): string =
  case s.kind:
    of ip4:
      return s.ip4.toBinaryString
    of ip6:
      return s.ip6.toBinaryString

proc ipAddress*(a: int32): Ip4Address =
  copyMem(addr result, a.unsafeAddr, 4)

proc ipAddress*(a: uint32): Ip4Address =
  copyMem(addr result, a.unsafeAddr, 4)

proc ipAddress*(a: array[16, char]): Ip6Address =
  var a = a
  copyMem(addr result, addr a, 16)

proc ipAddress*(a: array[16, byte]): Ip6Address =
  var a = a
  copyMem(addr result, addr a, 16)

proc ipAddress*(a: array[4, char]): Ip4Address =
  var a = a
  copyMem(addr result, addr a, 4)

proc ipAddress*(a: array[4, byte]): Ip4Address =
  var a = a
  copyMem(addr result, addr a, 4)

converter from4*(a: Ip4Address): IpAddress =
  result.kind = ip4
  result.ip4 = a

converter from6*(a: Ip6Address): IpAddress =
  result.kind = ip6
  result.ip6 = a

proc `[]`*(a: Ip4Address, index: int): uint8 = array[4, uint8](a)[index]
proc `[]`*(a: Ip6Address, index: int): uint8 = array[16, uint8](a)[index]
proc `[]`*(a: IpAddress, index: int): uint8 =
  case a.kind:
  of ip4: return a.ip4[index]
  of ip6: return a.ip6[index]

proc `$`*(a: Ip4Address): string =
  "$1.$2.$3.$4" % [$a[0], $a[1], $a[2], $a[3]]

proc `$`*(a: Ip6Address): string =
  var s = ""
  for i in 0..7:
    s.add a[2*i].int.toHex(2)
    s.add a[2*i+1].int.toHex(2)
    if i != 7: s.add ":"
  return s

proc `$`*(a: IpAddress): string =
  case a.kind:
  of ip4: return $a.ip4
  of ip6: return $a.ip6

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
  let parts = a.split(".").map(a => parseInt(a).uint8)
  if parts.len != 4:
    raise newException(ValueError, "invalid IP4 address ($1)" % [$a])
  [parts[0], parts[1], parts[2], parts[3]].Ip4Address

proc parseAddress*(a: string): IpAddress =
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
