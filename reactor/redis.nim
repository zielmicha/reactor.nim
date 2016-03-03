import strutils, macros
import reactor/async, reactor/tcp

type
  RedisError* = object of Exception

proc readError(stream: ByteStream): Future[ref RedisError] {.async.} =
  let excString = (await stream.readLine()).strip()
  return newException(RedisError, excString)

proc readInt(stream: ByteStream): Future[int64] {.async.} =
  let s = (await stream.readLine()).strip()
  if s.len == 0:
    asyncRaise newException(RedisError, "EOF")
  return parseBiggestInt(s)

proc unserialize*(stream: ByteStream, typ: typedesc[string]): Future[string] {.async.} =
  let ch = (await stream.read(1))
  if ch == "-":
    asyncRaise (await stream.readError())
  elif ch == "+":
    let line = await stream.readLine()
    if line.len < 2:
      asyncRaise newException(RedisError, "protocol error")
    return line[0..<line.len - 2]
  elif ch == "$":
    let len = (await stream.readInt())
    if len == -1:
      return nil
    let body = await stream.read(len.int)
    if (await stream.read(2)) != "\r\L":
      asyncRaise newException(RedisError, "protocol error")
    return body
  else:
    asyncRaise newException(RedisError, "unexpected type")

proc unserialize*(stream: ByteStream, typ: typedesc[int64]): Future[int64] {.async.} =
  let ch = (await stream.read(1))
  if ch == "-":
    asyncRaise (await stream.readError())
  elif ch == ":":
    return (await stream.readInt())
  else:
    asyncRaise newException(RedisError, "unexpected type")

proc unserialize*(stream: ByteStream, typ: typedesc[void]): Future[void] {.async.} =
  discard (await unserialize(stream, string))

proc unserialize*[T](stream: ByteStream, typ: typedesc[seq[T]]): Future[seq[T]] {.async.} =
  let ch = (await stream.read(1))
  if ch == "-":
    asyncRaise (await stream.readError())
  elif ch == "*":
    let len = (await stream.readInt())
    if len == -1:
      return nil
    var resp: seq[T] = @[]
    for i in 0..<(len.int):
      resp.add(await unserialize(stream, typ))
    return resp
  else:
    asyncRaise newException(RedisError, "unexpected type")

proc serialize*[T](output: ByteProvider, val: seq[T]): Future[void] {.async.} =
  if val == nil:
    await output.write("*-1\r\n")
  else:
    await output.write("*" & ($val.len) & "\r\n")
    for item in val:
      await output.serialize(item)

proc serialize*(output: ByteProvider, val: int64): Future[void] {.async.} =
  await output.write(":" & ($val) & "\r\n")

proc serialize*(output: ByteProvider, val: string): Future[void] {.async.} =
  if val == nil:
    await output.write("$-1\r\n")
  await output.write("$" & ($val.len) & "\r\n")
  await output.write(val)
  await output.write("\r\n")

type
  RedisClient* = ref object
    pipe: BytePipe
    pipelineQueue: SerialQueue

proc wrapRedis*(pipe: BytePipe): RedisClient =
  ## Create Redis client from existing connection.
  RedisClient(pipe: pipe, pipelineQueue: newSerialQueue())

proc connect*(host: string="127.0.0.1", port: int=6379): Future[RedisClient] {.async.} =
  ## Connect to Redis TCP instance.
  return wrapRedis(await connectTcp(host, port))

proc call*[R](client: RedisClient, cmd: seq[string], resp: typedesc[R]): Future[R] {.async.} =
  ## Perform a Redis call.
  let unserializeFunc = (proc(): Future[R] = unserialize(client.pipe.input, R))
  let resp = await (client.pipelineQueue.enqueue(unserializeFunc))
  await client.pipe.output.serialize(cmd)
  when R is void:
    await resp
  else:
    return (await resp)

macro defCommand*(sname: untyped, args: untyped, rettype: untyped): stmt =
  let name = newIdentNode(sname.strVal.toLower)
  let defArgs = newNimNode(nnkFormalParams).add(newNimNode(nnkEmpty))
  defArgs.add(newNimNode(nnkIdentDefs).add(newIdentNode("client"), newIdentNode("RedisClient"), newNimNode(nnkEmpty)))

  let callArgs = newNimNode(nnkBracket).add(sname)

  for arg in args:
    let name = arg[0]
    let typ = arg[1]
    defArgs.add(newNimNode(nnkIdentDefs).add(name, typ, newNimNode(nnkEmpty)))

    callArgs.add(newCall(newIdentNode("$"), name))

  let r = quote do:
    proc `name` (): Future[`rettype`] =
      client.call(@`callArgs`, `rettype`)

  defArgs[0] = r[0][3][0]
  r[0][3] = defArgs
  return r

defCommand("APPEND", [(key, string), (value, string)], int64)
defCommand("AUTH", [(key, string), (value, string)], void)
defCommand("DEL", [(key, string)], int64)
defCommand("DECR", [(key, string)], int64)
defCommand("DECRBY", [(key, string), (decrby, int64)], int64)
defCommand("EXPIRE", [(key, string), (seconds, int64)], int64)
defCommand("EXPIREAT", [(key, string), (timestamp, int64)], int64)
defCommand("EXISTS", [(key, string)], void)
defCommand("FLUSHALL", [], int64)
defCommand("GET", [(key, string)], string)
defCommand("GETSET", [(key, string), (value, string)], string)
defCommand("HDEL", [(key, string), (field, string)], int64)
defCommand("HEXISTS", [(key, string), (field, string)], int64)
defCommand("HGET", [(key, string), (field, string)], string)
#defCommand("HGETALL", [(key, string)], seq[string])
defCommand("HINCRBY", [(key, string), (field, string), (increment, int64)], int64)
defCommand("HINCRBYFLOAT", [(key, string), (field, string), (increment, string)], string)
#defCommand("HKEYS", [(key, string)], seq[string])
defCommand("HSET", [(key, string), (field, string), (value, string)], string)
#defCommand("HVALS", [(key, string)], seq[string])
defCommand("INCR", [(key, string)], int64)
defCommand("INCRBY", [(key, string), (decrby, int64)], int64)
#defCommand("KEYS", [(pattern, string)], seq[string])

when isMainModule:
  proc main() {.async.} =
    let redis = await connect()
    redis.append("reactor-test:list", "100").await.echo

  main().runMain()
