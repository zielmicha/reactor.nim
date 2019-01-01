import reactor/async, reactor/http/httpcommon, reactor/http/httpclient, options

type
  HttpSession* = ref object
    connectionFactory: (proc(r: HttpRequest): Future[HttpConnection])
    transformRequest: (proc(r: HttpRequest))
    baseUrl: string

proc defaultHttpSession(): HttpSession =
  return nil

proc defaultIfNil(sess: HttpSession): HttpSession =
  if sess == nil:
    return defaultHttpSession()
  else:
    return sess

proc createHttpSession*(connectionFactory: (proc(r: HttpRequest): Future[HttpConnection]),
                       transformRequest: (proc(r: HttpRequest))): HttpSession =
  return HttpSession(connectionFactory: connectionFactory, transformRequest: transformRequest)

proc createRequest*(sess: HttpSession, req: HttpRequest): HttpRequest =
  let newReq = new(HttpRequest)
  newReq[] = req[]
  let sess = defaultIfNil(sess)
  sess.transformRequest(newReq)
  return newReq

proc makeConnection*(sess: HttpSession, req: HttpRequest): Future[HttpConnection] {.async.} =
  return sess.connectionFactory(req)

proc request*(sess: HttpSession, httpMethod: string, url: string, data: any=none(string), headers=initHeaderTable()): Future[HttpResponse] {.async.} =
  let req = newHttpRequest(httpMethod, url, headers, data)
  let conn = await sess.makeConnection(req)
  # defer: conn.conn.close (?)
  return conn.request(sess.createRequest(req))
