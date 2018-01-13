# TESTdisabled.
discard """GET / HTTP/1.0
Host: www.atomshare.net
read: hello"""

import reactor/async, reactor/loop, reactor/tls, reactor/tcp, strutils, reactor/time

let port = 9002

proc client() {.async.} =
  await asyncSleep(200)
  let conn = await connectTcp("localhost", port)
  let wrapped = wrapTls(conn)
  await wrapped.handshakeAsClient(verify=false)
  await wrapped.output.write("GET / HTTP/1.0\r\LHost: www.atomshare.net\r\L\r\L")
  asyncFor line in wrapped.input.lines():
    echo "read: ", line.strip()

proc server() {.async.} =
  let srv = await createTcpServer(port, "localhost")
  let client = await srv.incomingConnections.receive()
  let wrapped = wrapTls(client)
  await wrapped.handshakeAsServer(certificateFile="tests/demo.crt", keyFile="tests/demo.key")
  echo((await wrapped.input.readLine()).strip())
  echo((await wrapped.input.readLine()).strip())
  await wrapped.output.write("hello")
  wrapped.close(JustClose)

proc main() {.async.} =
  await zip(@[client(), server()])

when isMainModule:
  main().runMain()
