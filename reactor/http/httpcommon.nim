import reactor/async, tables, strutils

type
  HeaderTable* = object
    headers: Table[string, string]

  HttpResponse* = ref object
    statusCode*: int
    headers*: HeaderTable
    dataStream*: ByteStream

  HttpRequest* = ref object
    httpMethod*: string
    path*: string
    headers*: HeaderTable
    dataLength*: int64
    data*: ByteStream

converter headerTable*(arr: openarray[tuple[k: string, v: string]]): HeaderTable =
  result.headers = initTable[string, string]()
  for item in arr:
    let (key, value) = item
    result.headers[key.strip.toLower] = value.strip

proc initHeaderTable*(): HeaderTable =
  result.headers = initTable[string, string]()

proc `[]`*(self: HeaderTable, key: string): string =
  return self.headers[key.strip.toLower]

proc `[]=`*(self: var HeaderTable, key: string, value: string) =
  self.headers[key.strip.toLower] = value.strip

proc getOrDefault*(self: HeaderTable, key: string, defaultVal: string): string =
  var key = key.strip.toLower
  if key notin self.headers:
    return defaultVal
  else:
    return self.headers[key]

proc contains*(self: HeaderTable, key: string): bool =
  return contains(self.headers, key.strip.toLower)

iterator pairs*(self: HeaderTable): tuple[k: string, v: string] =
  for k, v in self.headers:
    yield (k, v)

proc len*(self: HeaderTable): int =
  self.headers.len

#

proc newHttpRequest*(httpMethod: string, path: string, headers: HeaderTable=initHeaderTable(), data: string=nil): HttpRequest =
  HttpRequest(dataLength: if data == nil: -1 else: data.len,
              data: if data == nil: newConstStream(data) else: nil,
              headers: headers,
              path: path,
              httpMethod: httpMethod)

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
  var val = val
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
  var val = val
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
