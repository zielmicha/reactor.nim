# Based on OpneSSL wrappers from Nim's stdlib
# (c) Copyright 2015 Andreas Rumpf

## OpenSSL support

{.deadCodeElim: on.}

const useWinVersion = defined(Windows) or defined(nimdoc)

when useWinVersion:
  when not defined(nimOldDlls) and defined(cpu64):
    const
      DLLSSLName = "(ssleay64|libssl64).dll"
      DLLUtilName = "libeay64.dll"
  else:
    const
      DLLSSLName = "(ssleay32|libssl32).dll"
      DLLUtilName = "libeay32.dll"

  from winlean import SocketHandle
else:
  const
    versions = "(|.10|.1.0.1|.1.0.0|.0.9.9|.0.9.8)"
  when defined(macosx):
    const
      DLLSSLName = "libssl" & versions & ".dylib"
      DLLUtilName = "libcrypto" & versions & ".dylib"
  else:
    const
      DLLSSLName = "libssl.so" & versions
      DLLUtilName = "libcrypto.so" & versions
  from posix import SocketHandle

type
  SslStruct {.final, pure.} = object
  SslPtr* = ptr SslStruct
  PSslPtr* = ptr SslPtr
  SslCtx* = ptr object
  PSSL_METHOD* = SslPtr
  PX509* = ptr object
  PX509_NAME* = SslPtr
  PEVP_MD* = SslPtr
  EVP_PKEY* = SslPtr
  PRSA* = SslPtr
  PASN1_UTCTIME* = SslPtr
  PASN1_cInt* = SslPtr
  PPasswdCb* = SslPtr
  PFunction* = proc () {.cdecl.}
  DES_cblock* = array[0..7, int8]
  PDES_cblock* = ptr DES_cblock
  des_ks_struct*{.final.} = object
    ks*: DES_cblock
    weak_key*: cInt

  des_key_schedule* = array[1..16, des_ks_struct]

type
  BIO_METHOD* = object
    `type`*: cint
    name*: cstring
    bwrite*: proc (a2: BIO; buf: cstring; num: cint): cint {.cdecl.}
    bread*: proc (a2: BIO; buf: cstring; num: cint): cint {.cdecl.}
    bputs*: proc (a2: BIO; buf: cstring): cint {.cdecl.}
    bgets*: proc (a2: BIO; buf: cstring; num: cint): cint {.cdecl.}
    ctrl*: proc (a2: BIO; a3: cint; a4: clong; a5: pointer): clong {.cdecl.}
    create*: proc (a2: BIO): cint {.cdecl.}
    destroy*: proc (a2: BIO): cint {.cdecl.}
    callback_ctrl*: proc (a2: BIO; a3: cint; a4: pointer): clong {.cdecl.}

  PBIO_METHOD* = ptr BIO_METHOD

  bio_st* = object
    `method`*: ptr BIO_METHOD # bio, mode, argp, argi, argl, ret
    callback*: proc (a2: ptr bio_st; a3: cint; a4: cstring; a5: cint; a6: clong;
                     a7: clong): clong {.cdecl.}
    cb_arg*: cstring          # first argument for the callback
    init*: cint
    shutdown*: cint
    flags*: cint              # extra storage
    retry_reason*: cint
    num*: cint
    `ptr`*: pointer
    next_bio*: ptr bio_st     # used by filter BIOs
    prev_bio*: ptr bio_st     # used by filter BIOs
    references*: cint
    num_read*: uint64
    num_write*: uint64
    #ex_data*: CRYPTO_EX_DATA

  BIO* = ptr bio_st

{.deprecated: [PSSL: SslPtr, PSSL_CTX: SslCtx, PBIO: BIO].}

const
  SSL_SENT_SHUTDOWN* = 1
  SSL_RECEIVED_SHUTDOWN* = 2
  EVP_MAX_MD_SIZE* = 16 + 20
  SSL_ERROR_NONE* = 0
  SSL_ERROR_SSL* = 1
  SSL_ERROR_WANT_READ* = 2
  SSL_ERROR_WANT_WRITE* = 3
  SSL_ERROR_WANT_X509_LOOKUP* = 4
  SSL_ERROR_SYSCALL* = 5      #look at error stack/return value/errno
  SSL_ERROR_ZERO_RETURN* = 6
  SSL_ERROR_WANT_CONNECT* = 7
  SSL_ERROR_WANT_ACCEPT* = 8
  SSL_CTRL_NEED_TMP_RSA* = 1
  SSL_CTRL_SET_TMP_RSA* = 2
  SSL_CTRL_SET_TMP_DH* = 3
  SSL_CTRL_SET_TMP_ECDH* = 4
  SSL_CTRL_SET_TMP_RSA_CB* = 5
  SSL_CTRL_SET_TMP_DH_CB* = 6
  SSL_CTRL_SET_TMP_ECDH_CB* = 7
  SSL_CTRL_GET_SESSION_REUSED* = 8
  SSL_CTRL_GET_CLIENT_CERT_REQUEST* = 9
  SSL_CTRL_GET_NUM_RENEGOTIATIONS* = 10
  SSL_CTRL_CLEAR_NUM_RENEGOTIATIONS* = 11
  SSL_CTRL_GET_TOTAL_RENEGOTIATIONS* = 12
  SSL_CTRL_GET_FLAGS* = 13
  SSL_CTRL_EXTRA_CHAIN_CERT* = 14
  SSL_CTRL_SET_MSG_CALLBACK* = 15
  SSL_CTRL_SET_MSG_CALLBACK_ARG* = 16 # only applies to datagram connections
  SSL_CTRL_SET_MTU* = 17      # Stats
  SSL_CTRL_SESS_NUMBER* = 20
  SSL_CTRL_SESS_CONNECT* = 21
  SSL_CTRL_SESS_CONNECT_GOOD* = 22
  SSL_CTRL_SESS_CONNECT_RENEGOTIATE* = 23
  SSL_CTRL_SESS_ACCEPT* = 24
  SSL_CTRL_SESS_ACCEPT_GOOD* = 25
  SSL_CTRL_SESS_ACCEPT_RENEGOTIATE* = 26
  SSL_CTRL_SESS_HIT* = 27
  SSL_CTRL_SESS_CB_HIT* = 28
  SSL_CTRL_SESS_MISSES* = 29
  SSL_CTRL_SESS_TIMEOUTS* = 30
  SSL_CTRL_SESS_CACHE_FULL* = 31
  SSL_CTRL_OPTIONS* = 32
  SSL_CTRL_MODE* = 33
  SSL_CTRL_GET_READ_AHEAD* = 40
  SSL_CTRL_SET_READ_AHEAD* = 41
  SSL_CTRL_SET_SESS_CACHE_SIZE* = 42
  SSL_CTRL_GET_SESS_CACHE_SIZE* = 43
  SSL_CTRL_SET_SESS_CACHE_MODE* = 44
  SSL_CTRL_GET_SESS_CACHE_MODE* = 45
  SSL_CTRL_GET_MAX_CERT_LIST* = 50
  SSL_CTRL_SET_MAX_CERT_LIST* = 51 #* Allow SSL_write(..., n) to return r with 0 < r < n (i.e. report success
                                   # * when just a single record has been written): *
  SSL_CTRL_SET_TLSEXT_SERVERNAME_CB = 53
  SSL_CTRL_SET_TLSEXT_SERVERNAME_ARG = 54
  SSL_CTRL_SET_TLSEXT_HOSTNAME = 55
  TLSEXT_NAMETYPE_host_name* = 0
  SSL_TLSEXT_ERR_OK* = 0
  SSL_TLSEXT_ERR_ALERT_WARNING* = 1
  SSL_TLSEXT_ERR_ALERT_FATAL* = 2
  SSL_TLSEXT_ERR_NOACK* = 3
  SSL_MODE_ENABLE_PARTIAL_WRITE* = 1 #* Make it possible to retry SSL_write() with changed buffer location
                                     # * (buffer contents must stay the same!); this is not the default to avoid
                                     # * the misconception that non-blocking SSL_write() behaves like
                                     # * non-blocking write(): *
  SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER* = 2 #* Never bother the application with retries if the transport
                                           # * is blocking: *
  SSL_MODE_AUTO_RETRY* = 4    #* Don't attempt to automatically build certificate chain *
  SSL_MODE_NO_AUTO_CHAIN* = 8
  SSL_OP_NO_SSLv2* = 0x01000000
  SSL_OP_NO_SSLv3* = 0x02000000
  SSL_OP_NO_TLSv1* = 0x04000000
  SSL_OP_ALL* = 0x000FFFFF
  SSL_VERIFY_NONE* = 0x00000000
  SSL_VERIFY_PEER* = 0x00000001
  OPENSSL_DES_DECRYPT* = 0
  OPENSSL_DES_ENCRYPT* = 1
  X509_V_OK* = 0
  X509_V_ILLEGAL* = 1
  X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT* = 2
  X509_V_ERR_UNABLE_TO_GET_CRL* = 3
  X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE* = 4
  X509_V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE* = 5
  X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY* = 6
  X509_V_ERR_CERT_SIGNATURE_FAILURE* = 7
  X509_V_ERR_CRL_SIGNATURE_FAILURE* = 8
  X509_V_ERR_CERT_NOT_YET_VALID* = 9
  X509_V_ERR_CERT_HAS_EXPIRED* = 10
  X509_V_ERR_CRL_NOT_YET_VALID* = 11
  X509_V_ERR_CRL_HAS_EXPIRED* = 12
  X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD* = 13
  X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD* = 14
  X509_V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD* = 15
  X509_V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD* = 16
  X509_V_ERR_OUT_OF_MEM* = 17
  X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT* = 18
  X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN* = 19
  X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY* = 20
  X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE* = 21
  X509_V_ERR_CERT_CHAIN_TOO_LONG* = 22
  X509_V_ERR_CERT_REVOKED* = 23
  X509_V_ERR_INVALID_CA* = 24
  X509_V_ERR_PATH_LENGTH_EXCEEDED* = 25
  X509_V_ERR_INVALID_PURPOSE* = 26
  X509_V_ERR_CERT_UNTRUSTED* = 27
  X509_V_ERR_CERT_REJECTED* = 28 #These are 'informational' when looking for issuer cert
  X509_V_ERR_SUBJECT_ISSUER_MISMATCH* = 29
  X509_V_ERR_AKID_SKID_MISMATCH* = 30
  X509_V_ERR_AKID_ISSUER_SERIAL_MISMATCH* = 31
  X509_V_ERR_KEYUSAGE_NO_CERTSIGN* = 32
  X509_V_ERR_UNABLE_TO_GET_CRL_ISSUER* = 33
  X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION* = 34 #The application is not happy
  X509_V_ERR_APPLICATION_VERIFICATION* = 50
  SSL_FILETYPE_ASN1* = 2
  SSL_FILETYPE_PEM* = 1
  EVP_PKEY_RSA* = 6           # libssl.dll

  BIO_FLAGS_READ* = 0x01
  BIO_FLAGS_WRITE* = 0x02
  BIO_FLAGS_IO_SPECIAL* = 0x04
  BIO_FLAGS_SHOULD_RETRY* = 0x08


  BIO_C_SET_CONNECT = 100
  BIO_C_DO_STATE_MACHINE = 101
  BIO_C_GET_SSL = 110

const
  BIO_CTRL_RESET* = 1
  BIO_CTRL_EOF* = 2
  BIO_CTRL_INFO* = 3
  BIO_CTRL_SET* = 4
  BIO_CTRL_GET* = 5
  BIO_CTRL_PUSH* = 6
  BIO_CTRL_POP* = 7
  BIO_CTRL_GET_CLOSE* = 8
  BIO_CTRL_SET_CLOSE* = 9
  BIO_CTRL_PENDING_const* = 10
  BIO_CTRL_FLUSH* = 11
  BIO_CTRL_DUP* = 12
  BIO_CTRL_WPENDING* = 13

proc SSL_library_init*(): cInt{.cdecl, dynlib: DLLSSLName, importc, discardable.}
proc SSL_load_error_strings*(){.cdecl, dynlib: DLLSSLName, importc.}
proc ERR_load_BIO_strings*(){.cdecl, dynlib: DLLUtilName, importc.}

proc SSLv23_client_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}
proc SSLv23_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}
proc SSLv2_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}
proc SSLv3_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}
proc TLSv1_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}
proc TLSv1_1_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}
proc TLSv1_2_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}
proc TLS_method*(): PSSL_METHOD{.cdecl, dynlib: DLLSSLName, importc.}

proc SSL_new*(context: SslCtx): SslPtr{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_free*(ssl: SslPtr){.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_new*(meth: PSSL_METHOD): SslCtx{.cdecl,
    dynlib: DLLSSLName, importc.}
proc SSL_CTX_load_verify_locations*(ctx: SslCtx, CAfile: cstring,
    CApath: cstring): cInt{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_free*(arg0: SslCtx){.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_set_verify*(s: SslCtx, mode: int, cb: proc (a: int, b: pointer): int {.cdecl.}){.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_get_verify_result*(ssl: SslPtr): int{.cdecl,
    dynlib: DLLSSLName, importc.}
proc SSL_set_verify*(s: SslPtr, mode: int, cb: proc (a: int, b: pointer): int {.cdecl.}){.cdecl, dynlib: DLLSSLName, importc.}

proc SSL_CTX_set_cipher_list*(s: SslCtx, ciphers: cstring): cint{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_set_cipher_list*(s: SslPtr, ciphers: cstring): cint{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_use_certificate_file*(ctx: SslCtx, filename: cstring, typ: cInt): cInt{.
    stdcall, dynlib: DLLSSLName, importc.}
proc SSL_CTX_use_certificate_chain_file*(ctx: SslCtx, filename: cstring): cInt{.
    stdcall, dynlib: DLLSSLName, importc.}
proc SSL_use_certificate_file*(ctx: SslPtr, filename: cstring, typ: cInt): cInt{.
    stdcall, dynlib: DLLSSLName, importc.}
proc SSL_use_certificate_chain_file*(ctx: SslPtr, filename: cstring): cInt{.
    stdcall, dynlib: DLLSSLName, importc.}
proc SSL_use_PrivateKey_file*(ctx: SslPtr,
    filename: cstring, typ: cInt): cInt{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_use_PrivateKey_file*(ctx: SslCtx,
    filename: cstring, typ: cInt): cInt{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_check_private_key*(ctx: SslCtx): cInt{.cdecl, dynlib: DLLSSLName,
    importc.}

proc SSL_set_fd*(ssl: SslPtr, fd: SocketHandle): cint{.cdecl, dynlib: DLLSSLName, importc.}

proc SSL_CTX_get_ex_new_index*(argl: clong, argp: pointer, new_func: pointer, dup_func: pointer, free_func: pointer): cint {.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_set_ex_data*(ssl: SslCtx, idx: cint, arg: pointer): cint {.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_CTX_get_ex_data*(ssl: SslCtx, idx: cint): pointer {.cdecl, dynlib: DLLSSLName, importc.}

proc SSL_get_ex_new_index*(argl: clong, argp: pointer, new_func: pointer, dup_func: pointer, free_func: pointer): cint {.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_set_ex_data*(ssl: SslPtr, idx: cint, arg: pointer): cint {.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_get_ex_data*(ssl: SslPtr, idx: cint): pointer {.cdecl, dynlib: DLLSSLName, importc.}

proc SSL_get_peer_certificate*(ssl: SslPtr): PX509 {.cdecl, dynlib: DLLSSLName, importc.}

proc SSL_shutdown*(ssl: SslPtr): cInt{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_set_shutdown*(ssl: SslPtr, mode: cint) {.cdecl, dynlib: DLLSSLName, importc: "SSL_set_shutdown".}
proc SSL_get_shutdown*(ssl: SslPtr): cint {.cdecl, dynlib: DLLSSLName, importc: "SSL_get_shutdown".}
proc SSL_connect*(ssl: SslPtr): cint{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_read*(ssl: SslPtr, buf: pointer, num: cint): cint{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_write*(ssl: SslPtr, buf: cstring, num: cint): cint{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_get_error*(s: SslPtr, ret_code: cInt): cInt{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_accept*(ssl: SslPtr): cInt{.cdecl, dynlib: DLLSSLName, importc.}
proc SSL_pending*(ssl: SslPtr): cInt{.cdecl, dynlib: DLLSSLName, importc.}

proc BIO_new_ssl_connect*(ctx: SslCtx): BIO{.cdecl,
    dynlib: DLLSSLName, importc.}
proc BIO_ctrl*(bio: BIO, cmd: cint, larg: int, arg: cstring): int{.cdecl,
    dynlib: DLLSSLName, importc.}
proc BIO_get_ssl*(bio: BIO, ssl: ptr SslPtr): int =
  return BIO_ctrl(bio, BIO_C_GET_SSL, 0, cast[cstring](ssl))
proc BIO_set_conn_hostname*(bio: BIO, name: cstring): int =
  return BIO_ctrl(bio, BIO_C_SET_CONNECT, 0, name)
proc BIO_do_handshake*(bio: BIO): int =
  return BIO_ctrl(bio, BIO_C_DO_STATE_MACHINE, 0, nil)
proc BIO_do_connect*(bio: BIO): int =
  return BIO_do_handshake(bio)

proc BIO_set_flags*(b: BIO, flags: cint) {.cdecl,
    dynlib: DLLSSLName, importc.}
proc BIO_clear_flags*(b: BIO, flags: cint) {.cdecl,
    dynlib: DLLSSLName, importc.}

when not defined(nimfix):
  proc BIO_read*(b: BIO, data: cstring, length: cInt): cInt{.cdecl,
      dynlib: DLLUtilName, importc.}
  proc BIO_write*(b: BIO, data: cstring, length: cInt): cInt{.cdecl,
      dynlib: DLLUtilName, importc.}

proc BIO_free*(b: BIO): cInt{.cdecl, dynlib: DLLUtilName, importc.}

proc ERR_print_errors_fp*(fp: File){.cdecl, dynlib: DLLSSLName, importc.}

proc ERR_error_string*(e: cInt, buf: cstring): cstring{.cdecl,
    dynlib: DLLUtilName, importc.}
proc ERR_error_string_n*(e: cInt, buf: cstring, len: int) {.cdecl,
    dynlib: DLLUtilName, importc.}
proc ERR_get_error*(): cInt{.cdecl, dynlib: DLLUtilName, importc.}
proc ERR_peek_last_error*(): cInt{.cdecl, dynlib: DLLUtilName, importc.}

proc OpenSSL_add_all_algorithms*(){.cdecl, dynlib: DLLUtilName, importc: "OPENSSL_add_all_algorithms_conf".}

proc OPENSSL_config*(configName: cstring){.cdecl, dynlib: DLLSSLName, importc.}

when not useWinVersion:
  proc CRYPTO_set_mem_functions(a,b,c: pointer){.cdecl,
    dynlib: DLLUtilName, importc.}

  proc allocWrapper(size: int): pointer {.cdecl.} = alloc(size)
  proc reallocWrapper(p: pointer; newsize: int): pointer {.cdecl.} =
    if p == nil:
      if newSize > 0: result = alloc(newsize)
    elif newsize == 0: dealloc(p)
    else: result = realloc(p, newsize)
  proc deallocWrapper(p: pointer) {.cdecl.} =
    if p != nil: dealloc(p)

proc CRYPTO_malloc_init*() =
  when not useWinVersion and not defined(macosx):
    CRYPTO_set_mem_functions(allocWrapper, reallocWrapper, deallocWrapper)

proc SSL_CTX_ctrl*(ctx: SslCtx, cmd: cInt, larg: int, parg: pointer): int{.
  cdecl, dynlib: DLLSSLName, importc.}

proc SSL_CTX_callback_ctrl(ctx: SslCtx, typ: cInt, fp: PFunction): int{.
  cdecl, dynlib: DLLSSLName, importc.}

proc SSLCTXSetMode*(ctx: SslCtx, mode: int): int =
  result = SSL_CTX_ctrl(ctx, SSL_CTRL_MODE, mode, nil)

proc SSL_ctrl*(ssl: SslPtr, cmd: cInt, larg: int, parg: pointer): int{.
  cdecl, dynlib: DLLSSLName, importc.}

proc SSL_set_tlsext_host_name*(ssl: SslPtr, name: cstring): int =
  result = SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, TLSEXT_NAMETYPE_host_name, name)
  ## Set the SNI server name extension to be used in a client hello.
  ## Returns 1 if SNI was set, 0 if current SSL configuration doesn't support SNI.


proc SSL_get_servername*(ssl: SslPtr, typ: cInt = TLSEXT_NAMETYPE_host_name): cstring {.cdecl, dynlib: DLLSSLName, importc.}
  ## Retrieve the server name requested in the client hello. This can be used
  ## in the callback set in `SSL_CTX_set_tlsext_servername_callback` to
  ## implement virtual hosting. May return `nil`.

proc SSL_CTX_set_tlsext_servername_callback*(ctx: SslCtx, cb: proc(ssl: SslPtr, cb_id: int, arg: pointer): int {.cdecl.}): int =
  ## Set the callback to be used on listening SSL connections when the client hello is received.
  ##
  ## The callback should return one of:
  ## * SSL_TLSEXT_ERR_OK
  ## * SSL_TLSEXT_ERR_ALERT_WARNING
  ## * SSL_TLSEXT_ERR_ALERT_FATAL
  ## * SSL_TLSEXT_ERR_NOACK
  result = SSL_CTX_callback_ctrl(ctx, SSL_CTRL_SET_TLSEXT_SERVERNAME_CB, cast[PFunction](cb))

proc SSL_CTX_set_tlsext_servername_arg*(ctx: SslCtx, arg: pointer): int =
  ## Set the pointer to be used in the callback registered to ``SSL_CTX_set_tlsext_servername_callback``.
  result = SSL_CTX_ctrl(ctx, SSL_CTRL_SET_TLSEXT_SERVERNAME_ARG, 0, arg)


proc BIO_new*(b: PBIO_METHOD): BIO{.cdecl, dynlib: DLLUtilName, importc: "BIO_new".}
proc BIO_free_all*(b: BIO){.cdecl, dynlib: DLLUtilName, importc: "BIO_free_all".}
proc BIO_s_mem*(): PBIO_METHOD{.cdecl, dynlib: DLLUtilName, importc: "BIO_s_mem".}
proc BIO_ctrl_pending*(b: BIO): cInt{.cdecl, dynlib: DLLUtilName, importc: "BIO_ctrl_pending".}
proc BIO_read*(b: BIO, Buf: cstring, length: cInt): cInt{.cdecl,
    dynlib: DLLUtilName, importc: "BIO_read".}
proc BIO_write*(b: BIO, Buf: cstring, length: cInt): cInt{.cdecl,
    dynlib: DLLUtilName, importc: "BIO_write".}

proc SSL_set_connect_state*(s: SslPtr) {.cdecl,
    dynlib: DLLSSLName, importc: "SSL_set_connect_state".}
proc SSL_set_accept_state*(s: SslPtr) {.cdecl,
    dynlib: DLLSSLName, importc: "SSL_set_accept_state".}

proc SSL_read*(ssl: SslPtr, buf: cstring, num: cInt): cInt{.cdecl,
      dynlib: DLLSSLName, importc: "SSL_read".}
proc SSL_peek*(ssl: SslPtr, buf: cstring, num: cInt): cInt{.cdecl,
    dynlib: DLLSSLName, importc: "SSL_peek".}

proc SSL_set_bio*(ssl: SslPtr, rbio, wbio: BIO) {.cdecl,
    dynlib: DLLSSLName, importc: "SSL_set_bio".}

proc SSL_do_handshake*(ssl: SslPtr): cint {.cdecl,
    dynlib: DLLSSLName, importc: "SSL_do_handshake".}

