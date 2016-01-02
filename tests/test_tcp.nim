import reactor/tcp, reactor/loop, reactor/async, reactor/util, reactor/ipaddress

proc acceptConn(conn: TcpConnection) =
  echo "got connection"
  conn.input.forEachChunk(proc(x: seq[byte]) =
                          var x = x
                          echo ":", x
                          discard conn.output.provideSome(x.seqView)).ignore()

proc main(x: TcpServer) =
  x.incomingConnections.forEach(acceptConn).ignore()

let srv = createTcpServer(6666)
srv.then(main).ignore()

runLoop()
