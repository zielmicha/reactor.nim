# TEST.
discard """closing stream
|hello world|
error(nil)
will now exit"""
import reactor/tcp, reactor/loop, reactor/async, reactor/util, reactor/ipaddress, reactor/time

proc main() {.async.} =
  let srv = await createTcpServer(6669)

  await asyncSleep(100)

  let conn = await connectTcp("localhost", 6669)
  let client = await srv.incomingConnections.receive()
  let data = "hello world"
  await conn.output.write(data)
  close(conn, JustClose)

  let recvData = await client.input.read(data.len)
  echo "|", recvData, "|"
  let recved = tryAwait client.input.read(5)
  echo recved
  echo "will now exit"

main().runLoop()
