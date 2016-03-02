import reactor/async, reactor/udp, reactor/resolv

proc main() {.async.} =
  let server = newUdpSocket()
  await server.bindAddress("localhost", 9060)

  let destAddr = await resolveSingleAddress("localhost")
  let client = newUdpSocket()
  await client.output.provide(UdpPacket(data: "hello", dest: (destAddr, 9060)))

  let pkt = await server.input.receive()
  echo "recv ", pkt.data

when isMainModule:
  main().runMain()
