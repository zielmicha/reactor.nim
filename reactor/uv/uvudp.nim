import reactor/async, reactor/ipaddress, reactor/resolv
import reactor/uv/uv, reactor/uv/uvutil, posix

type
  UdpPacket* = ref object
    data*: string
    source*: tuple[address: IpAddress, port: int]
    dest*: tuple[address: IpAddress, port: int]

  UdpSocket* = ref object of Pipe[UdpPacket]
    handle: ptr uv_udp_t
    inputProvider: Output[UdpPacket]
    outputStream: Input[UdpPacket]
    alreadyBound: bool

proc handleOutput(sock: UdpSocket) {.async.} =
  while true:
    let packet = await sock.outputStream.receive()

    let sockaddress = cast[ptr SockAddr](alloc0(sizeof(Sockaddr_storage)))
    ipaddrToSockaddr(sockaddress, packet.dest.address, packet.dest.port)
    var buf: uv_buf_t = uv_buf_t(base: addr packet.data[0], len: packet.data.len)
    discard uv_udp_try_send(sock.handle, addr buf, 1, sockaddress)
    dealloc(sockaddress)

proc deallocUdpSock(sock: UdpSocket) =
  sock.handle.data = nil
  uv_close(sock.handle, freeUvMemory)

proc newUdpSocket*(): UdpSocket =
  var socket: UdpSocket
  new(socket, deallocUdpSock)
  socket.handle = cast[ptr uv_udp_t](newUvHandle(UV_UDP))
  checkZero "udp_init", uv_udp_init(getThreadUvLoop(), socket.handle)

  (socket.input, socket.inputProvider) = newInputOutputPair[UdpPacket]()
  (socket.outputStream, socket.output) = newInputOutputPair[UdpPacket]()

  socket.handleOutput().onErrorClose(socket.outputStream)

  socket.inputProvider.onSendReady.addListener proc() =
    if socket.inputProvider.isRecvClosed:
      deallocUdpSock(socket)

  return socket

proc allocCb(stream: ptr uv_handle_t, suggestedSize: csize, buf: ptr uv_buf_t) {.cdecl.} =
  buf.base = alloc0(suggestedSize)
  buf.len = suggestedSize

proc recvCb(handle: ptr uv_udp_t; nread: int; buf: ptr uv_buf_t; `addr`: ptr SockAddr; flags: cuint) {.cdecl.} =
  defer: dealloc(buf.base)

  if handle.data == nil:
    return

  let socket = cast[UdpSocket](handle.data)
  if nread <= 0 or (flags and UV_UDP_PARTIAL.cuint) != 0:
    return

  let packet = UdpPacket()
  packet.data = newString(nread)
  copyMem(addr packet.data[0], buf.base, nread)
  packet.source = sockaddrToIpaddr(`addr`)

  if socket.inputProvider.freeBufferSize > 0:
    discard socket.inputProvider.provide(packet)

proc bindAddress*(socket: UdpSocket, host: IpAddress, port: int): Result[void] =
  assert(not socket.alreadyBound)
  socket.alreadyBound = true

  let sockaddress = cast[ptr SockAddr](alloc0(sizeof(Sockaddr_storage)))
  ipaddrToSockaddr(sockaddress, host, port)
  let err = uv_udp_bind(socket.handle, sockaddress, 0)
  dealloc(sockaddress)
  if err != 0:
    return error(void, uvError(err, "couldn't bind UDP socket"))

  GC_ref(socket)
  socket.handle.data = cast[pointer](socket)

  checkZero "recv_start", uv_udp_recv_start(socket.handle, allocCb.uv_alloc_cb, recvCb.uv_udp_recv_cb)
  return just()

proc bindAddress*(socket: UdpSocket, host: string, port: int): Future[void] {.async.} =
  let address = await resolveSingleAddress(host)
  await bindAddress(socket, address, port)
