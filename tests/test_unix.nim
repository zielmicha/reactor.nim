import reactor, reactor/unix

proc handleServer(s: UnixServer) {.async.} =
  asyncFor conn in s.incomingConnections:
    echo "got connection"
    echo(await conn.input.read(10))
    conn.input.recvClose JustClose
    conn.output.sendClose JustClose

proc main() {.async.} =
  let server = createUnixServer("/tmp/unix123")
  handleServer(server).ignore

  let conn = await connectUnix("/tmp/unix123")
  await conn.output.write("hello world")

  let conn2 = await connectUnix("/tmp/unix123")
  await conn2.output.write("hello world")
  echo "read:", tryAwait conn2.input.readSome(maxCount=100)

when isMainModule:
  main().runMain
