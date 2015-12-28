import reactor/util
import reactor/loop
import reactor/async
import reactor/uv, reactor/uv/uvutil

type
  TcpIncomingConnection* = object
    discard

  TcpServer* = object
    incomingConnections* = Stream[TcpIncomingConnection]

  TcpConnection* = object
    discard

proc createTcpServer*(port: int, host="localhost"): TcpServer =

  checkZero "bind", uv_tcp_bind(server, cast[ptr SockAddr](addr address), 0)


proc acceptAll*(server: TcpServer): Stream[TcpConnection] =
  server.incomingConnections.map((incoming: TcpIncomingConnection) => incoming.accept())

proc accept*(incomingConn: TcpIncomingConnection): TcpConnection =
  nil
