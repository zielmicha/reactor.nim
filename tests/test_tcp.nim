import reactor/tcp, reactor/loop, reactor/async, reactor/util, reactor/ipaddress

proc acceptConn(conn: TcpConnection) =
  echo "got connection"
  conn.input.forEachChunk(proc(x: seq[byte]) =
                          var x = x
                          echo ":", x
                          discard conn.output.provideSome(x.seqView)).
      onError(proc(err: ref Exception) = conn.output.sendClose(err))

proc main(x: TcpServer) =
  connectTcp("127.0.0.1", 6666).then(proc(conn: TcpConnection) =
    var s = @[byte(0), byte(0), byte(0)]
    discard conn.output.provideSome(s.seqView.viewToConstView)
    conn.output.sendClose(JustClose)).ignore()
  x.incomingConnections.forEach(acceptConn).ignore()

let srv = createTcpServer(6666)
srv.then(main).ignore()

runLoop()
