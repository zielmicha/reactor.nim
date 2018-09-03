import strutils, macros, times
import reactor/async, reactor/tcp, reactor/time

type
  RedisError* = object of Exception

proc readError(input: ByteInput): Future[ref RedisError] {.async.} =
  let excString = (await input.readLine()).strip()
  return newException(RedisError, excString)

proc readInt(input: ByteInput): Future[int64] {.async.} =
  let s = (await input.readLine()).strip()
  if s.len == 0:
    asyncRaise newException(RedisError, "EOF")
  return parseBiggestInt(s)

proc unserialize*(input: ByteInput, typ: typedesc[string]): Future[string] {.async.} =
  let ch = (await input.read(1))
  if ch == "-":
    let err = await input.readError()
    asyncRaise err
  elif ch == "+":
    let line = await input.readLine()
    if line.len < 2:
      asyncRaise newException(RedisError, "protocol error")
    return line[0..<line.len - 2]
  elif ch == "$":
    let len = (await input.readInt())
    if len == -1:
      return ""
    let body = await input.read(len.int)
    if (await input.read(2)) != "\r\L":
      asyncRaise newException(RedisError, "protocol error")
    return body
  else:
    asyncRaise newException(RedisError, "unexpected type")

proc unserialize*(input: ByteInput, typ: typedesc[int64]): Future[int64] {.async.} =
  let ch = (await input.read(1))
  if ch == "-":
    let err = (await input.readError())
    asyncRaise err
  elif ch == ":":
    let val = (await input.readInt())
    return val
  else:
    asyncRaise newException(RedisError, "unexpected type")

proc unserialize*(input: ByteInput, typ: typedesc[void]): Future[void] {.async.} =
  discard (await unserialize(input, string))

proc unserialize*[T](input: ByteInput, typ: typedesc[seq[T]]): Future[seq[T]] {.async.} =
  let ch = (await input.read(1))
  if ch == "-":
    let err = (await input.readError())
    asyncRaise err
  elif ch == "*":
    let len = (await input.readInt())
    if len == -1:
      return @[]
    var resp: seq[T] = @[]
    for i in 0..<(len.int):
      let val = await unserialize(input, T)
      resp.add(val)
    return resp
  else:
    asyncRaise newException(RedisError, "unexpected type")

proc serialize*[T](output: ByteOutput, val: seq[T]): Future[void] {.async.} =
  await output.write("*" & ($val.len) & "\r\n")
  for item in val:
    await output.serialize(item)

proc serialize*(output: ByteOutput, val: int64): Future[void] {.async.} =
  await output.write(":" & ($val) & "\r\n")

proc serialize*(output: ByteOutput, val: string): Future[void] {.async.} =
  await output.write("$" & ($val.len) & "\r\n")
  await output.write(val)
  await output.write("\r\n")

type
  RedisClient* = ref object
    pipe*: BytePipe
    sendMutex: AsyncMutex
    connectProc: (proc(client: RedisClient): Future[void])
    reconnectFlag: bool

proc wrapRedis*(connectProc: (proc(client: RedisClient): Future[void]), reconnect=false): RedisClient =
  ## Create Redis client from existing connection. connectProc should assign connection to `pipe` attribute of `client`.
  RedisClient(sendMutex: newAsyncMutex(), connectProc: connectProc, reconnectFlag: reconnect)

proc reconnect*(client: RedisClient) {.async.} =
  if client.pipe != nil:
    client.pipe.close JustClose

  while true:
    let fut = (client.connectProc)(client)
    let ret = tryAwait fut
    if ret.isError:
      stderr.writeLine("connection to Redis failed: " & ($ret))
      await asyncSleep(1000)
    else:
      break

proc maybeReconnect(client: RedisClient) {.async.} =
  if not client.reconnectFlag and client.pipe != nil:
    return

  await client.reconnect

proc isConnected*(client: RedisClient): bool =
  return client.pipe != nil and not client.pipe.output.isRecvClosed

proc call*[R](client: RedisClient, cmd: seq[string], resp: typedesc[R]): Future[R] {.async.} =
  ## Perform a Redis call.
  when defined(timeRedis):
    let start = epochTime()

  await client.sendMutex.lock
  if not client.isConnected:
    await client.maybeReconnect()

  var resp: Future[R]

  asyncDefer: client.sendMutex.unlock # correct?
  await client.pipe.output.serialize(cmd)
  resp = unserialize(client.pipe.input, R)

  when R is void:
    await resp
  else:
    let val = (await resp)

  when defined(timeRedis):
    echo cmd[0], " took ", (epochTime() - start) * 1000, " ms"

  when R is not void:
    return val

macro defCommand*(sname: untyped, args: untyped, rettype: untyped): untyped =
  let name = newIdentNode(sname.strVal.toLowerAscii)
  let defArgs = newNimNode(nnkFormalParams).add(newNimNode(nnkEmpty))
  defArgs.add(newNimNode(nnkIdentDefs).add(newIdentNode("client"), newIdentNode("RedisClient"), newNimNode(nnkEmpty)))

  let callArgs = newNimNode(nnkBracket).add(sname)

  for arg in args:
    let name = arg[0]
    let typ = arg[1]
    defArgs.add(newNimNode(nnkIdentDefs).add(name, typ, newNimNode(nnkEmpty)))

    callArgs.add(newCall(newIdentNode("$"), name))

  let r = quote do:
    proc `name`* (): Future[`rettype`] =
      client.call(@`callArgs`, `rettype`)

  defArgs[0] = r[3][0]
  r[3] = defArgs
  return r

defCommand("APPEND", [(key, string), (value, string)], int64)
defCommand("AUTH", [(password, string)], void)
defCommand("DEL", [(key, string)], int64)
defCommand("DECR", [(key, string)], int64)
defCommand("DECRBY", [(key, string), (decrby, int64)], int64)
defCommand("EXPIRE", [(key, string), (seconds, int64)], int64)
defCommand("EXPIREAT", [(key, string), (timestamp, int64)], int64)
defCommand("EXISTS", [(key, string)], void)
defCommand("FLUSHALL", [], int64)
defCommand("GET", [(key, string)], string)
defCommand("GETSET", [(key, string), (value, string)], string)
defCommand("SET", [(key, string), (value, string)], string)
defCommand("SETEX", [(key, string), (value, string), (timeout, string)], string)
defCommand("HDEL", [(key, string), (field, string)], int64)
defCommand("HEXISTS", [(key, string), (field, string)], int64)
defCommand("HGET", [(key, string), (field, string)], string)
#defCommand("HGETALL", [(key, string)], seq[string])
defCommand("HINCRBY", [(key, string), (field, string), (increment, int64)], int64)
defCommand("HINCRBYFLOAT", [(key, string), (field, string), (increment, string)], string)
#defCommand("HKEYS", [(key, string)], seq[string])
defCommand("HSET", [(key, string), (field, string), (value, string)], int64)
#defCommand("HVALS", [(key, string)], seq[string])
defCommand("INCR", [(key, string)], int64)
defCommand("INCRBY", [(key, string), (decrby, int64)], int64)
#defCommand("KEYS", [(pattern, string)], seq[string])
defCommand("PUBLISH", [(channel, string), (message, string)], int64)

type
  RedisMessage* = object
    channel*: string
    message*: string

proc expectSubscribeConfirmation(input: ByteInput) {.async.} =
  let ch = (await input.read(1))
  if ch == "*":
    let len = (await input.readInt())
    if len != 3:
      asyncRaise newException(RedisError, "unexpected array length")
    if (await unserialize(input, string)) != "subscribe":
      asyncRaise newException(RedisError, "unexpected event")
    discard (await unserialize(input, string))
    discard (await unserialize(input, int64))
  else:
    asyncRaise newException(RedisError, "unexpected type")

proc pubsubStart(client: RedisClient, channels: seq[string]) {.async.} =
  await client.pipe.output.serialize(@["SUBSCRIBE"] & channels)

  for ch in channels:
    await client.pipe.input.expectSubscribeConfirmation()

proc pubsub*(client: RedisClient, channels: seq[string]): Input[RedisMessage] {.asynciterator.} =
  ## Start listening for PUBSUB messages on channels `channels`.
  var reconnect = false
  while true:
    if client.pipe == nil or client.pipe.output.isRecvClosed or reconnect:
      if not client.reconnectFlag and client.pipe != nil:
        asyncRaise "socket closed"

      await client.maybeReconnect()
      reconnect = false
      if (tryAwait client.pubsubStart(channels)).isError:
        stderr.writeLine "Could not start pubsub channel"
        await asyncSleep(500)
        reconnect = true
        continue

    let fut: Future[seq[string]] = unserialize(client.pipe.input, seq[string])
    let respR = tryAwait fut
    if respR.isError:
      stderr.writeLine("pubsub channel disconnected (" & $respR & ")")
      await asyncSleep(500)
      reconnect = true
      continue

    let resp: seq[string] = respR.get
    if resp[0] == "message":
      asyncYield RedisMessage(channel: resp[1], message: resp[2])


proc connectProc(client: RedisClient, host: string, port: int, password: string) {.async.} =
  client.pipe = await connectTcp(host, port)
  if password != "":
    await client.auth(password)

proc connect*(host: string="127.0.0.1", port: int=6379, password: string = "", reconnect=false): RedisClient =
  ## Connect to Redis TCP instance.

  return wrapRedis((proc(client: RedisClient): Future[void] = connectProc(client, host, port, password)), reconnect=reconnect)

when isMainModule:
  proc startListening() {.async.} =
    let redis = await connect(reconnect=true)
    let messages = redis.pubsub(@["foo"])
    asyncFor item in messages:
      echo "got message: ", item

  proc main() {.async.} =
    echo "running..."
    startListening().ignore()
    let redis = await connect(reconnect=true)
    let resp = await redis.append("reactor-test:list", "100")
    echo resp

    while true:
      await asyncSleep(500)
      discard (await redis.publish("foo", "hello"))

  main().runMain()
