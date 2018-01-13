import reactor, reactor/unix

proc handleServer(s: UnixServer) {.async.} =
  asyncFor conn in s.incomingConnections:
    echo "got connection"
    let res = await conn.input.read(10)
    echo res
    conn.input.recvClose JustClose
    conn.output.sendClose JustClose

proc main() {.async.} =
  let server = createUnixServer("/tmp/unix123")
  handleServer(server).ignore

  let conn = await connectUnix("/tmp/unix123")
  await conn.output.write("hello world")

  let conn2 = await connectUnix("/tmp/unix123")
  await conn2.output.write("hello world")
  let res = tryAwait conn2.input.readSome(maxCount=100)
  echo "read:", res

when isMainModule:
  main().runMain
