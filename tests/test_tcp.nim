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
    conn.output.writeItem(5.uint32).ignore()
    conn.input.readItem(uint32).then(proc(x: uint32) = echo x).ignore()).ignore()
  x.incomingConnections.forEach(acceptConn).ignore()

let srv = createTcpServer(6666)
srv.then(main).ignore()

runLoop()
