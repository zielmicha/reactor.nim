import strutils, macros, times
import reactor/async, reactor/tcp, reactor/time, collections, reactor/unix

type
  RedisError* = object of Exception

  RedisClient* = ref object
    connected: bool
    readers: Output[proc(): Future[void]]
    output: ByteOutput
    input: ByteInput
    sendMutex: AsyncMutex
    connectProc: (proc(): Future[BytePipe])
    reconnectFlag: bool
    password: string

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

proc wrapRedis*(connectProc: (proc(): Future[BytePipe]), password="", reconnect=false): RedisClient =
  ## Create Redis client from existing connection.
  RedisClient(sendMutex: newAsyncMutex(), connectProc: connectProc, password: password, reconnectFlag: reconnect)

proc maybeReconnect(client: RedisClient) {.async.}

proc disconnect(client: RedisClient) =
  client.output.sendClose JustClose
  client.readers.sendClose JustClose

proc call*[R](client: RedisClient, cmd: seq[string], resp: typedesc[R], lock=true): Future[R] {.async.} =
  ## Perform a Redis call.
  var resp: Future[R]

  when defined(debugRedis):
    stderr.writeLine "call " & $cmd

  await client.maybeReconnect

  let completer = newCompleter[R]()

  proc reader() {.async.} =
    let res = tryAwait unserialize(client.input, R)
    completer.complete(res)

  await client.sendMutex.lock
  let fut1 = tryAwait client.readers.send(reader)
  let fut2 = tryAwait client.output.serialize(cmd)
  client.sendMutex.unlock

  if fut1.isError or fut2.isError:
    client.disconnect

  fut1.get
  fut2.get

  when R is void:
    await completer.getFuture
  else:
    return completer.getFuture

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
defCommand("SETEX", [(key, string), (timeout, string), (value, string)], string)
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

proc pubsubStart(pipe: BytePipe, channels: seq[string]) {.async.} =
  await pipe.output.serialize(@["SUBSCRIBE"] & channels)

  for ch in channels:
    await pipe.input.expectSubscribeConfirmation()

proc connectPubsub*(connectProc: (proc(): Future[BytePipe]), password: string, channels: seq[string]): Input[RedisMessage] {.asynciterator.} =
  ## Start listening for PUBSUB messages on channels `channels`.
  var pipe: BytePipe = nil
  while true:
    if pipe == nil or pipe.output.isRecvClosed:
      if pipe != nil: pipe.close
      pipe = await connectProc()
      if password != "":
        await pipe.output.serialize(@["AUTH", password])
        await pipe.input.unserialize(void)

      if (tryAwait pipe.pubsubStart(channels)).isError:
        stderr.writeLine "Could not start pubsub channel"
        await asyncSleep(500)
        continue

    let fut: Future[seq[string]] = unserialize(pipe.input, seq[string])
    let respR = tryAwait fut
    if respR.isError:
      stderr.writeLine("pubsub channel disconnected (" & $respR & ")")
      await asyncSleep(500)
      pipe.close
      continue

    let resp: seq[string] = respR.get
    if resp[0] == "message":
      asyncYield RedisMessage(channel: resp[1], message: resp[2])

proc pubsub*(client: RedisClient, channels: seq[string]): Input[RedisMessage]=
  return connectPubsub(client.connectProc, client.password, channels)

proc doReconnect(client: RedisClient) {.async.} =
  var x = await client.connectProc()

  defer:
    if x != nil: x.close

  if client.password != "":
    await x.output.serialize(@["AUTH", client.password])
    await x.input.unserialize(void)

  if client.input != nil:
    client.input.recvClose
    client.output.sendClose

  client.output = x.output
  client.input = x.input

  x = nil # prevent from closing by defer

  client.connected = true
  var readersIn: Input[proc():Future[void]]
  (readersIn, client.readers) = newInputOutputPair[proc():Future[void]]()

  proc reader() {.async.} =
    asyncFor reader in readersIn:
      await reader()

  reader().onErrorClose(readersIn)

proc reconnect*(client: RedisClient, maybe=false) {.async.} =
  await client.sendMutex.lock
  asyncDefer: client.sendMutex.unlock

  if maybe:
    if client.connected:
      return

    if not client.reconnectFlag and client.input != nil:
      return

  if client.connected:
    client.output.sendClose JustClose
    client.readers.sendClose JustClose

  while true:
    let fut = client.doReconnect()
    let ret = tryAwait fut
    if ret.isError:
      stderr.writeLine("connection to Redis failed: " & ($ret))
      await asyncSleep(1000)
    else:
      break

proc maybeReconnect(client: RedisClient) {.async.} =
  await client.reconnect(maybe=true)

proc connect*(address = "", password = "", reconnect=false): RedisClient =
  ## Connect to Redis TCP instance.

  proc connectProc(): Future[BytePipe] {.async.} =
    when defined(debugRedis):
      echo "connect to Redis at ", address
    if address.startswith("/"):
      return connectUnix(address).then(x => x.BytePipe)
    else:
      return connectTcp(if ":" in address: address else: address & ":6379").then(x => x.BytePipe)

  return wrapRedis(connectProc, password, reconnect=reconnect)

proc connect*(host: string, port: int, password: string = "", reconnect=false): RedisClient =
  ## Connect to Redis TCP instance.
  return connect("[" & host & "]:" & $port, password)

when isMainModule:
  proc startListening() {.async.} =
    let redis = connect(reconnect=true)
    let messages = redis.pubsub(@["foo"])
    asyncFor item in messages:
      echo "got message: ", item

  proc main() {.async.} =
    echo "running..."
    startListening().ignore()
    let redis = connect(reconnect=true)
    let resp = await redis.append("reactor-test:list", "100")
    echo resp

    while true:
      await asyncSleep(500)
      discard (await redis.publish("foo", "hello"))

  main().runMain()
