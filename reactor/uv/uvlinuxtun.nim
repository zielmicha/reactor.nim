import reactor/async, reactor/loop
import reactor/uv/uv, reactor/uv/uvutil, reactor/uv/uvmsgstream
import reactor/linux/iface, reactor/linux/if_tun
import posix

proc openTunFd(name: string): Result[cint] =
  let fd = posix.open("/dev/net/tun", O_RDWR)
  if fd < 0:
    return error(cint, osError("open tun"))

  var req: ifreq
  var name = name
  zeroMem(addr req, sizeof req)
  req.ifr_ifru.ifru_flags = IFF_TUN
  copyMem(addr req.ifrn_name, addr name[0], min(sizeof(req.ifrn_name) - 1, name.len))
  if ioctl(fd, TUNSETIFF.uint, addr req) < 0:
    return error(cint, osError("ioctl tun"))

  return just(fd)

proc openTun*(name: string): Future[MsgPipe] {.async.} =
  let fd = await openTunFd(name)
  return newMsgPipe(fd)

when isMainModule:
  from os import execShellCmd

  proc main() {.async.} =
    let tun = await openTun("mytun0")
    doAssert(execShellCmd("ifconfig mytun0 up 10.88.33.1/24") == 0)
    asyncFor packet in tun.input:
      echo(packet.repr)

  main().runMain()
