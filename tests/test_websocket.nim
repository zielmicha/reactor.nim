import reactor, reactor/http, reactor/http/websocket

proc callback(r: HttpRequest, conn: WebsocketConnection) {.async.} =
  defer: echo "fin"

  while true:
    let msg = await conn.readMessage
    echo msg
    await conn.writeMessage(msg.data)

proc main() {.async.} =
  await runHttpServer(port = 8005, callback = websocketServerCallback(callback))

when isMainModule:
  main().runMain
