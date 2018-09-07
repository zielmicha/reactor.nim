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
    data*: Option[LengthByteInput]

  HttpError* = object of Exception

proc tryParseUint64*(val: string): Result[int64]

converter headerTable*(arr: openarray[tuple[k: string, v: string]]): HeaderTable =
  result.headers = initTable[string, string]()
  for item in arr:
    let (key, value) = item
    result.headers[key.strip.toLowerAscii] = value.strip

proc initHeaderTable*(): HeaderTable =
  result.headers = initTable[string, string]()

proc `[]`*(self: HeaderTable, key: string): string =
  return self.headers[key.strip.toLowerAscii]

proc `[]=`*(self: var HeaderTable, key: string, value: string) =
  self.headers[key.strip.toLowerAscii] = value.strip

proc getOrDefault*(self: HeaderTable, key: string, defaultVal: string): string =
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

proc newHttpRequest*(httpMethod: string, path: string, host: string, headers: HeaderTable=initHeaderTable(), data: Option[LengthByteInput]=none(LengthByteInput), port: int=0, isSsl=false): HttpRequest =
  HttpRequest(data: data,
              headers: headers,
              path: path,
              port: port,
              isSsl: isSsl,
              httpMethod: httpMethod,
              host: host)

proc newHttpRequest*(httpMethod: string, url: string, headers: HeaderTable=initHeaderTable(), data: Option[LengthByteInput]=none(LengthByteInput)): HttpRequest =
  var isSsl: bool
  if url.startswith("https://"):
    isSsl = true
  elif url.startswith("http://"):
    isSsl = false
  else:
    raise newException(Exception, "invalid schema")

  let (_, rest) = url.split2("://")
  let s1 = rest.split("/", maxsplit=1)

  let path = if s1.len == 2: "/" & s1[1] else: "/"

  let s2 = s1[0].split(":", maxsplit=1)

  let port = if s2.len == 2: parseInt(s2[1]) else: (if isSsl: 443 else: 80)
  let host = s2[0]

  if port <= 0 or port >= 65536:
    raise newException(Exception, "invalid port")

  HttpRequest(httpMethod: httpMethod,
              path: path,
              host: host,
              port: port,
              isSsl: isSsl,
              headers: headers,
              data: data)

proc `$`*(req: HttpResponse): string =
  var headers: seq[string] = @[]
  for k, v in req.headers:
    headers.add("$1='$2'" % [k, v])
  return "HttpResponse(statusCode=$1, headers={$2})" % [$req.statusCode, headers.join(", ")]

proc `$`*(req: HttpRequest): string =
  var headers: seq[string] = @[]
  for k, v in req.headers:
    headers.add("$1='$2'" % [k, v])
  return "HttpRequest(httpMethod=$1, path=$2, headers={$3})" % [req.httpMethod, req.path, headers.join(", ")]

proc reverse(s: var string) =
  for i in 0..<(s.len/2).int:
    swap(s[i], s[s.len - 1 - i])

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
