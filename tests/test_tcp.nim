# TEST.
discard """ok
ok"""
import reactor/tcp, reactor/loop, reactor/async, reactor/util, reactor/ipaddress, reactor/time

proc acceptConn(conn: TcpConnection) =
  echo "got connection"

proc main() {.async.} =
  let srv = await createTcpServer(6669)

  await asyncSleep(2000)
  let conn = await connectTcp("localhost", 6669)
  echo "ok"
  let client = await srv.incomingConnections.receive()
  let data = "hello world\n"
  await conn.output.write(data)
  let recvData = await client.input.read(data.len)
  assert data == recvData
  echo "ok"

main().runLoop()
