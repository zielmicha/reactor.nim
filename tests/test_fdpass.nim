# TEST.
discard """accepted tcp conn
got connection
data: hello world
writing to stdout
write res:11
read:HELLO world"""

import reactor, reactor/unix, posix, os, reactor/tcp

proc handleServer(s: UnixServer, fd: cint) {.async.} =
  asyncFor conn in s.incomingConnections:
    echo "got connection"
    await conn.sendFd(fd, "hello world")
    #await conn.output.write("hello world")

proc acceptConn(s: TcpServer) {.async.} =
  asyncFor conn in s.incomingConnections:
    echo "accepted tcp conn"
    let data = await conn.input.read(11)
    echo "read:", data
    return

proc main() {.async.} =
  discard execShellCmd("rm /tmp/unix123 2>/dev/null")

  let tcpServer = await createTcpServer(5559)
  let tcpFuture = acceptConn(tcpServer)

  let tcpClient = await connectTcpAsFd(TcpConnectionData(host: parseAddress("127.0.0.1"), port: 5559))

  let server = createUnixServer("/tmp/unix123", allowFdPassing=true)
  handleServer(server, tcpClient).ignore

  let conn = await connectUnix("/tmp/unix123", allowFdPassing=true)

  let res = await conn.input.read(11)
  echo "data: ", res
  let child = await conn.acceptFd

  echo "writing to stdout"
  let res1 = posix.write(child, cstring("HELLO world"), 11)
  echo "write res:", res1

  await tcpFuture

when isMainModule:
  main().runMain
