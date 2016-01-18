include reactor/uv/uvtcp
import strutils

proc connectTcp*(address: string): Future[TcpConnection] =
  if ":" notin address:
    raise newException(ValueError, ": not in TCP address")
  let port = address[address.rfind(":")+1..^(-1)].parseInt
  let hostname = address[0..<address.rfind(":")]
  return connectTcp(hostname, port)
