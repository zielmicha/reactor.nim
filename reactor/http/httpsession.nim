import reactor/async, reactor/http/httpcommon, reactor/http/httpclient, options

type
  HttpSession* = ref object
    conn: HttpConnection
    baseUrl: string
    headers: HeaderTable

proc defaultHttpSession(): HttpSession =
  return nil

proc defaultIfNil(sess: HttpSession): HttpSession =
  if sess == nil:
    return defaultHttpSession()
  else:
    return sess

proc request*(sess: HttpSession, httpMethod: string, url: string, data=none(string), headers=initHeaderTable()): Future[HttpResponse] {.async.} =
  let sess = defaultIfNil(sess)
  var finHeaders = sess.headers
  for k, v in headers:
    finHeaders[k] = v

  let finUrl = sess.baseUrl & url
  newHttpRequest(httpMethod, finUrl, headers, data)
