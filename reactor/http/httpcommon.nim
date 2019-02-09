import reactor/async, collections

type
  HeaderTable* = object
    headers: Table[string, string]

  HttpResponse* = ref object
    statusCode*: int
    headers*: HeaderTable
    dataInput*: ByteInput

  HttpRequest* = ref object
    host*: string
    port*: int
    isSsl*: bool

    httpMethod*: string
    path*: string
    headers*: HeaderTable
    data*: Option[ByteInput]

  HttpError* = object of Exception

proc tryParseUint64*(val: string): Result[int64]

converter headerTable*(arr: openarray[tuple[k: string, v: string]]): HeaderTable =
  result.headers = initTable[string, string]()
  for item in arr:
    let (key, value) = item
    result.headers[key.strip.toLowerAscii] = value.strip

proc initHeaderTable*(): HeaderTable =
  result.headers = initTable[string, string]()

proc del*(self: var HeaderTable, key: string) =
  self.headers.del key.strip.toLowerAscii

proc `[]`*(self: HeaderTable, key: string): string =
  return self.headers[key.strip.toLowerAscii]

proc `[]=`*(self: var HeaderTable, key: string, value: string) =
  self.headers[key.strip.toLowerAscii] = value.strip

proc `$`*(self: HeaderTable): string =
  $(self.headers)

proc getOrDefault*(self: HeaderTable, key: string, defaultVal: string=""): string =
  var key = key.strip.toLowerAscii
  if key notin self.headers:
    return defaultVal
  else:
    return self.headers[key]

proc contains*(self: HeaderTable, key: string): bool =
  return contains(self.headers, key.strip.toLowerAscii)

iterator pairs*(self: HeaderTable): tuple[k: string, v: string] =
  for k, v in self.headers:
    yield (k, v)

proc len*(self: HeaderTable): int =
  self.headers.len

#

proc makeData(x: ByteInput, headers: var HeaderTable): Option[ByteInput] =
  return some(x)

proc makeData(x: LengthByteInput, headers: var HeaderTable): Option[ByteInput] =
  headers["content-length"] = $(x.length)
  return some(x.stream)

proc makeData(x: string, headers: var HeaderTable): Option[ByteInput] =
  return makeData(newLengthInput(x), headers)

proc makeData(x: Option, headers: var HeaderTable): Option[ByteInput] =
  if x.isSome:
    return makeData(x.get, headers)
  else:
    return none(ByteInput)

proc newHttpRequest*(httpMethod: string, path: string, host: string, headers: HeaderTable=initHeaderTable(), data: any=none(string), port: int=0, isSsl=false): HttpRequest =
  result = HttpRequest(
              headers: headers,
              path: path,
              port: port,
              isSsl: isSsl,
              httpMethod: httpMethod,
              host: host)
  result.data = makeData(data, result.headers)

proc newHttpRequest*(httpMethod: string, url: string, headers: HeaderTable=initHeaderTable(), data: any=none(string)): HttpRequest =
  if url.startswith("/"):
    return newHttpRequest(httpMethod, path=url, host="", headers=headers, data=data)

  var isSsl: bool
  if url.startswith("https://"):
    isSsl = true
  elif url.startswith("http://"):
    isSsl = false
  else:
    raise newException(Exception, "invalid schema ($1)" % url)

  let (_, rest) = url.split2("://")
  let s1 = rest.split("/", maxsplit=1)

  let path = if s1.len == 2: "/" & s1[1] else: "/"

  let s2 = s1[0].split(":", maxsplit=1)

  let port = if s2.len == 2: parseInt(s2[1]) else: (if isSsl: 443 else: 80)
  let host = s2[0]

  if port <= 0 or port >= 65536:
    raise newException(Exception, "invalid port")

  newHttpRequest(httpMethod = httpMethod,
                 path = path,
                 host = host,
                 port = port,
                 isSsl = isSsl,
                 headers = headers,
                 data = data)

proc `$`*(req: HttpResponse): string =
  if req == nil: return "nil"
  var headers: seq[string] = @[]
  for k, v in req.headers:
    headers.add("$1='$2'" % [k, v])
  return "HttpResponse(statusCode=$1, headers={$2})" % [$req.statusCode, headers.join(", ")]

proc `$`*(req: HttpRequest): string =
  if req == nil: return "nil"
  var headers: seq[string] = @[]
  for k, v in req.headers:
    headers.add("$1='$2'" % [k, v])
  return "HttpRequest(httpMethod=$1, path=$2, headers={$3})" % [req.httpMethod, req.path, headers.join(", ")]

proc tryParseHexUint64*(val: string): Result[int64] =
  var val = val.strip
  if val.len > 15:
    return error(int64, "integer too large")

  var res: int64 = 0
  for ch in val:
    case ch
    of '0'..'9':
      res = res shl 4 or (ord(ch) - ord('0')).int64
    of 'a'..'f':
      res = res shl 4 or (ord(ch) - ord('a') + 10).int64
    of 'A'..'F':
      res = res shl 4 or (ord(ch) - ord('A') + 10).int64
    else: return error(int64, "invalid hex integer: " & val)

  return just(res)

proc tryParseUint64*(val: string): Result[int64] =
  var val = val.strip
  if val.len > 19:
    return error(int64, "integer too large")

  var res: int64 = 0
  for ch in val:
    case ch
    of '0'..'9':
      res *= 10
      res += (ord(ch) - ord('0')).int64
    else:
      return error(int64, "invalid integer: " & val.repr)

  return just(res)

proc hasOnlyChars*(val: string, s: set[char]): bool =
  for ch in val:
    if ch notin s:
      return false
  return true

func query*(r: HttpRequest): string =
  return if '?' in r.path: "?" & r.path.split('?', 1)[1] else: ""

func splitPath*(r: HttpRequest): seq[string] =
  result = r.path.split('?')[0][1..^1].split('/')
  if result.len > 0 and result[^1] == "":
     discard result.pop

proc urlEncode*(s: string): string =
  const allowed = {'a'..'z', 'A'..'Z', '0'..'9', '-', '.', '_', '~'}
  for ch in s:
    if ch in allowed:
      result &= ch
    else:
      result &= '%'
      result &= toHex(ord(ch), 2)

proc urlDecode*(s: string): string =
  var i = 0
  while i < s.len:
    if s[i] == '%' and i+2 < s.len:
      result.add parseHexInt(s[i+1..i+2]).char
      i += 3
    else:
      result.add s[i]
      i += 1

proc encodeQuery*(r: openarray[(string, string)]): string =
  if r.len == 0: return ""
  for item in r:
    result &= urlEncode(item[0])
    result &= "="
    result &= urlEncode(item[1])
    result &= "&"

  result.setLen(result.len - 1)

proc decodeQuery*(r: string): seq[(string, string)] =
  var r = r
  if r.len == 0: return @[]
  if r.startswith("?"): r = r[1..^1]
  for item in r.split("&"):
    let v = item.split("=", 1)
    if v.len > 1:
      result.add((urlDecode(v[0]), urlDecode(v[1])))

proc getQueryParam*(r: HttpRequest, key: string): string =
  for item in decodeQuery(r.query):
    if item[0] == key: return item[1]

  return ""

proc newHttpResponse*(data: string, statusCode: int=200, headers=initHeaderTable()): HttpResponse =
  var headers = headers
  headers["content-length"] = $(data.len)
  return HttpResponse(
    statusCode: statusCode,
    headers: headers,
    dataInput: newConstInput(data),
  )
