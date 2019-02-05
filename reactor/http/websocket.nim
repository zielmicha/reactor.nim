import reactor/async, collections, std/sha1, base64
import reactor/http/httpcommon, reactor/http/httpimpl

const messageLengthLimit = 10_000_000

proc websocketServerHandshake(r: HttpRequest): HttpResponse =
  if r.headers.getOrDefault("connection").toLowerAscii != "upgrade":
    return newHttpResponse("expected websocket upgrade", statusCode=400)

  let upgrades = r.headers.getOrDefault("Upgrade").split(", ")
  if "websocket" notin upgrades:
    return newHttpResponse("expected websocket upgrade", statusCode=400)

  let key = r.headers.getOrDefault("Sec-WebSocket-Key")
  let acceptKey = base64.encode(
    decodeHex($secureHash(key & "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")),
    newline=""
  )

  let resp = HttpResponse(statusCode: 101)
  resp.headers = headerTable({
    "Upgrade": "websocket",
    "Connection": "Upgrade",
    "Sec-WebSocket-Version": "13",
    "Sec-WebSocket-Accept": acceptKey
  })
  return resp

type
  WebsocketFrame = ref object
    data: string
    opcode: int
    fin: bool

  WebsocketMessageKind* = enum
    binary, text

  WebsocketMessage* = object
    data*: Buffer
    kind*: WebsocketMessageKind

  WebsocketConnection* = ref object
    writeMutex: AsyncMutex
    rawOutput: ByteOutput
    rawInput: ByteInput

proc readFrame(i: ByteInput): Future[WebsocketFrame] {.async.} =
  let flags = await i.readItem(uint16, bigEndian)
  let fin = ((flags shr 15) and 0b1) != 0
  let opcode = (flags shr 8) and 0b1111
  let mask = (flags and 0b1000_0000) != 0
  var payloadLen: uint64 = flags and 0b111_1111
  var maskingKey = "\0\0\0\0"

  if payloadLen == 126:
    payloadLen = await i.readItem(uint16, bigEndian)
  elif payloadLen == 127:
    payloadLen = await i.readItem(uint64, bigEndian)

  if payloadLen > uint64(messageLengthLimit):
    raise newException(Exception, "websocket message too large")

  if mask:
    maskingKey = await i.read(4)

  let frame = WebsocketFrame()
  frame.opcode = int(opcode)
  frame.fin = fin
  frame.data = await i.read(int(payloadLen))
  for i in 0..<frame.data.len:
    frame.data[i] = char(int(frame.data[i]) xor int(maskingKey[i mod 4]))

  return frame

proc writeFrame(i: WebsocketConnection, f: WebsocketFrame) {.async.} =
  await i.writeMutex.lock
  defer: i.writeMutex.unlock

  let fPayloadLen = if f.data.len < 126: f.data.len else: 126
  let flags = uint16(
    (1 shl 15) or # fin
    (int(f.opcode) shl 8) or
    fPayloadLen
  )
  await i.rawOutput.writeItem(flags, bigEndian)
  doAssert f.data.len <= int(high(uint16))
  if f.data.len >= 126:
    await i.rawOutput.writeItem(uint16(f.data.len), bigEndian)

  await i.rawOutput.write(f.data)

proc writeMessage*(i: WebsocketConnection, msg: WebsocketMessage) {.async.} =
  await i.writeFrame(WebsocketFrame(
    data: msg.data,
    opcode: case msg.kind:
              of WebsocketMessageKind.text: 0x01
              of WebsocketMessageKind.binary: 0x02
  ))

proc writeMessage*(i: WebsocketConnection, data: Buffer) {.async.} =
  await i.writeMessage(WebsocketMessage(data: data, kind: WebsocketMessageKind.binary))

proc readMessage*(i: WebsocketConnection): Future[WebsocketMessage] {.async.} =
  ## Read message from a websocket and reply to pings.

  var fragments: seq[WebsocketFrame]
  var totalLength = 0

  while true:
    let frame = await i.rawInput.readFrame
    if frame.opcode == 0x01 or frame.opcode == 0x02 or frame.opcode == 0x00:
      # data
      if frame.opcode != 0x00:
        if fragments.len != 0:
          raise newException(Exception, "new message started before previous one finished")
      else:
        if fragments.len == 0:
          raise newException(Exception, "message fragment received without message data")

      fragments.add(frame)
      totalLength += frame.data.len

      if totalLength > messageLengthLimit:
        raise newException(Exception, "websocket message too long")

      if frame.fin:
        let buf = newBuffer(totalLength)
        var pos = 0
        for f in fragments:
          buf.slice(pos).copyFrom(f.data)
          pos += f.data.len
        return WebsocketMessage(
          kind: if fragments[0].opcode == 0x01:
                  WebsocketMessageKind.text
                else:
                  WebsocketMessageKind.binary,
          data: buf
        )

    elif frame.opcode == 0x08:
      # close
      raise JustClose
    elif frame.opcode == 0x09:
      # ping
      await i.writeFrame(WebsocketFrame(opcode: 0x0A, fin: true, data: frame.data))
    elif frame.opcode == 0x0A:
      # pong
      discard

proc close*(conn: WebsocketConnection) =
  conn.rawInput.recvClose
  conn.rawOutput.sendClose

proc websocketStart(conn: WebsocketConnection, rawInput: ByteInput, rawOutput: ByteOutput) =
  conn.rawInput = rawInput
  conn.rawOutput = rawOutput

proc initWebsocketConnection(): WebsocketConnection =
  result = WebsocketConnection()
  result.writeMutex = newAsyncMutex()

proc websocketServer*(r: HttpRequest): (HttpResponse, WebsocketConnection) =
  let resp = websocketServerHandshake(r)
  if resp.statusCode != 101:
    return (resp, nil)

  let conn = initWebsocketConnection()
  let (input, output) = newInputOutputPair[byte]()
  resp.dataInput = input

  websocketStart(conn, r.data.get, output)
  return (resp, conn)

proc websocketServerCallback*(cb: (proc(r: HttpRequest, conn: WebsocketConnection): Future[void])): (proc(r: HttpRequest): Future[HttpResponse]) =
  return
    proc(r: HttpRequest): Future[HttpResponse] {.async.} =
      let (resp, conn) = websocketServer(r)
      cb(r, conn).onSuccessOrError(
        proc(r: Result[void]) =
          conn.close

          if r.isError and r.error.getOriginal != JustClose:
            r.error.printError
      )
      return resp
