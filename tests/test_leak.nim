import reactor, reactor/unix, tests/util_test

proc handleServer(s: UnixServer) {.async.} =
  asyncFor conn in s.incomingConnections:
    let res = await conn.input.read(5)
    assert res == "hello world"[0..<5]
    conn.close

proc main() {.async.} =
  echo getOccupiedMem()

  let server = createUnixServer("/tmp/unix123")
  handleServer(server).ignore

  proc sub() {.async.} =
    for i in 0..1_000:
      let e = tryAwait connectUnix("/tmp/unix123-doesntexist")
      assert e.isError

      let conn = await connectUnix("/tmp/unix123")
      await conn.output.write("hello world")
      conn.close

  await testLeaks(sub)

when isMainModule:
  main().runMain
