import reactor/async, reactor/tcp
import reactor/tls/opensslwrapper, reactor/tls/bio

var tlsStreamIndex: cint
var sslContext {.threadvar.}: SslCtx

type
  TlsPipe = ref object of BytePipe
    ssl: SslPtr
    pipe: BytePipe
    bio: BIO

  TlsError = object of Exception

proc init() =
  if sslContext != nil:
    return

  CRYPTO_malloc_init()
  SSL_library_init()
  SSL_load_error_strings()
  ERR_load_BIO_strings()
  OpenSSL_add_all_algorithms()

  sslContext = SSL_CTX_new(TLSv1_2_method()) # TODO: use TLSv1_2_method()
  discard SSL_CTX_load_verify_locations(sslContext, nil, "/etc/ssl/certs/")
  assert ssl_context != nil
  tlsStreamIndex = SSL_get_ex_new_index(0, nil, nil, nil, nil)

proc handleSslErr(self: TlsPipe, ret: cint) {.async.} =
  let err = SSL_get_error(self.ssl, ret)
  if err == SSL_ERROR_WANT_READ:
    await self.pipe.input.waitForData(allowSpurious=true)
  elif err == SSL_ERROR_WANT_WRITE:
    await self.pipe.output.waitForSpace(allowSpurious=true)
  elif err == SSL_ERROR_ZERO_RETURN:
    asyncRaise JustClose
  elif err == SSL_ERROR_SYSCALL:
    if ret == 0:
      asyncRaise newException(TlsError, "premature EOF in TLS stream")
    else:
      asyncRaise newException(TlsError, "TLS transport error (should not happen)")
  else:
    var error = ""
    var buf = newString(256)
    while true:
      let errInfo = ERR_get_error()
      if errInfo == 0:
        break
      ERR_error_string_n(errInfo, buf, buf.len);
      error &= $buf.cstring & "; "

    asyncRaise newException(TlsError, "TLS error: " & $error & " (code:" & $err & ", ret: " & $ret & ")")

proc tlsReader(self: TlsPipe): ByteStream =
  let (stream, provider) = newStreamProviderPair[byte]()

  proc pipeRead() {.async.} =
    var buffer = newString(4096)
    while true:
      let ret = SSL_read(self.ssl, buffer, buffer.len.cint)
      if ret <= 0:
        await self.handleSslErr(ret)
        continue

      var slice = buffer[0..<ret]
      slice.shallow
      await provider.write(slice)

  pipeRead().onErrorClose(provider)
  return stream

proc doCloseSsl(self: TlsPipe) {.async.} =
  let ret = SSL_shutdown(self.ssl)
  if ret <= 0:
    await self.handleSslErr(ret)

proc tlsWriter(self: TlsPipe): ByteProvider =
  let (stream, provider) = newStreamProviderPair[byte]()

  proc pipeWrite() {.async.} =
    while true:
      let view = stream.peekMany()
      if view.len == 0:
        let err = tryAwait stream.waitForData
        if err.isError:
          await self.doCloseSsl()
          asyncRaise err.error
        continue

      let ret = SSL_write(self.ssl, cast[cstring](view.data), view.len.cint)
      if ret <= 0:
        await self.handleSslErr(ret)
      else:
        assert ret == view.len
        stream.discardItems(view.len)

  pipeWrite().onErrorClose(stream)
  return provider

proc wrapTls*(pipe: BytePipe): TlsPipe =
  init() # FIXME: thread safety?
  let bio = wrapBio(pipe)
  let self = TlsPipe(pipe: pipe, bio: bio, ssl: SSL_new(sslContext))
  doAssert(self.ssl != nil)
  SSL_set_bio(self.ssl, self.bio, self.bio)
  GC_ref(self)
  doAssert(SSL_set_ex_data(self.ssl, tlsStreamIndex, cast[pointer](self)) == 1)

  return self

proc start(self: TlsPipe) =
  assert self.input == nil
  self.input = self.tlsReader()
  self.output = self.tlsWriter()

# see https://cipherli.st/
const goodServerCiphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH:ECDHE-RSA-AES128-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA128:DHE-RSA-AES128-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES128-GCM-SHA128:ECDHE-RSA-AES128-SHA384:ECDHE-RSA-AES128-SHA128:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES128-SHA128:DHE-RSA-AES128-SHA128:DHE-RSA-AES128-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA384:AES128-GCM-SHA128:AES128-SHA128:AES128-SHA128:AES128-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4"

# all ciphers with ECDSA or RSA
const goodClientCiphers = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DH-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-SHA256:DH-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:DH-RSA-AES256-SHA:DHE-RSA-CAMELLIA256-SHA:DH-RSA-CAMELLIA256-SHA:ECDH-RSA-AES256-GCM-SHA384:ECDH-ECDSA-AES256-GCM-SHA384:ECDH-RSA-AES256-SHA384:ECDH-ECDSA-AES256-SHA384:ECDH-RSA-AES256-SHA:ECDH-ECDSA-AES256-SHA:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:DH-RSA-AES128-GCM-SHA256:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES128-SHA256:DH-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DH-RSA-AES128-SHA:DHE-RSA-CAMELLIA128-SHA:DH-RSA-CAMELLIA128-SHA:ECDH-RSA-AES128-GCM-SHA256:ECDH-ECDSA-AES128-GCM-SHA256:ECDH-RSA-AES128-SHA256:ECDH-ECDSA-AES128-SHA256:ECDH-RSA-AES128-SHA:ECDH-ECDSA-AES128-SHA:ECDHE-RSA-RC4-SHA:ECDHE-ECDSA-RC4-SHA:ECDH-RSA-RC4-SHA:ECDH-ECDSA-RC4-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:DH-RSA-DES-CBC3-SHA:ECDH-RSA-DES-CBC3-SHA:ECDH-ECDSA-DES-CBC3-SHA:EDH-RSA-DES-CBC-SHA:DH-RSA-DES-CBC-SHA"

proc waitForHandshake(self: TlsPipe) {.async.} =
  while true:
    let ret = SSL_do_handshake(self.ssl)
    if ret <= 0:
      await self.handleSslErr(ret)
    else:
      break

proc handshakeAsClient*(self: TlsPipe, hostname: string=nil, verify=true) {.async.} =
  if hostname != nil:
    doAssert(SSL_set_tlsext_host_name(self.ssl, hostname) == 0)

  SSL_set_connect_state(self.ssl)
  if verify:
    doAssert(SSL_set_cipher_list(self.ssl, goodClientCiphers) == 1)
    SSL_set_verify(self.ssl, SSL_VERIFY_PEER, nil)

  await self.waitForHandshake()
  if verify:
    let cert = SSL_get_peer_certificate(self.ssl)
    if cert == nil:
      asyncRaise "missing certificate (unexpected)"

    # TODO: verify hostnames!

  self.start()

proc connectTls*(hostname: string, port: int): Future[TlsPipe] {.async.} =
  let conn = await connectTcp(hostname, port)
  let wrapped = wrapTls(conn)
  await wrapped.handshakeAsClient(hostname=hostname)
  return wrapped

proc handshakeAsServer*(self: TlsPipe, certificateFile: string, keyFile: string) {.async.} =
  doAssert(SSL_set_cipher_list(self.ssl, goodServerCiphers) == 1)
  SSL_set_accept_state(self.ssl)
  # TODO: use SSL_use_certificate_chain_file
  if SSL_use_certificate_file(self.ssl, certificateFile, SSL_FILETYPE_PEM) != 1:
    raise newException(TlsError, "failed to load certificate file")
  if SSL_use_PrivateKey_file(self.ssl, keyFile, SSL_FILETYPE_PEM) != 1:
    raise newException(TlsError, "failed to load key file")
  self.start()

proc close*(t: TlsPipe, err: ref Exception) =
  # why close doesn't work without this?
  BytePipe(t).close(err)
