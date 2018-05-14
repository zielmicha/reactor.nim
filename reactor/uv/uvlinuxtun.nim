import reactor/async, reactor/loop
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvmsgstream
import reactor/linux/iface, reactor/linux/if_tun
import posix

type TunTapMode* = enum
  modeTun,
  modeTap

proc openTunFd(name: string, mode: TunTapMode): Result[cint] =
  let fd = posix.open("/dev/net/tun", O_RDWR)
  if fd < 0:
    return error(cint, osError("open tun"))

  var req: ifreq
  var name = name
  zeroMem(addr req, sizeof req)
  # Open TUN without packet headers
  req.ifr_ifru.ifru_flags = IFF_NO_PI
  if mode == modeTun:
    req.ifr_ifru.ifru_flags = req.ifr_ifru.ifru_flags or IFF_TUN
  else:
    req.ifr_ifru.ifru_flags = req.ifr_ifru.ifru_flags or IFF_TAP

  copyMem(addr req.ifrn_name, addr name[0], min(sizeof(req.ifrn_name) - 1, name.len))
  if ioctl(fd, TUNSETIFF.uint, addr req) < 0:
    return error(cint, osError("ioctl tun"))

  return just(fd)

proc openTun*(name: string, mode=modeTun): Future[MsgPipe] {.async.} =
  let fd = await openTunFd(name, mode)
  return newMsgPipe(fd)

when isMainModule:
  from os import execShellCmd

  proc main() {.async.} =
    let tun = await openTun("mytun0")
    doAssert(execShellCmd("ifconfig mytun0 up 10.88.33.1/24") == 0)
    asyncFor packet in tun.input:
      echo(packet.repr)

  main().runMain()
