# nim flags -d:enableMtcp
import reactor/uv/uv, reactor/uv/uvutil

type
  socket_type {.size: sizeof(cint).} = enum
    MTCP_SOCK_UNUSED, MTCP_SOCK_STREAM, MTCP_SOCK_PROXY, MTCP_SOCK_LISTENER,
    MTCP_SOCK_EPOLL, MTCP_SOCK_PIPE

type
  mtcp_conf {.importc: "mtcp_conf", header: "<mtcp_api.h>".} = object
    num_cores {.importc: "num_cores".}: cint
    max_concurrency {.importc: "max_concurrency".}: cint
    max_num_buffers {.importc: "max_num_buffers".}: cint
    rcvbuf_size {.importc: "rcvbuf_size".}: cint
    sndbuf_size {.importc: "sndbuf_size".}: cint
    tcp_timewait {.importc: "tcp_timewait".}: cint
    tcp_timeout {.importc: "tcp_timeout".}: cint

  mctx_t = pointer

proc mtcp_init(config_file: cstring): cint {.cdecl, importc: "mtcp_init",
    header: "<mtcp_api.h>".}
proc mtcp_destroy() {.cdecl, importc: "mtcp_destroy", header: "<mtcp_api.h>".}
proc mtcp_getconf(conf: ptr mtcp_conf): cint {.cdecl, importc: "mtcp_getconf",
    header: "<mtcp_api.h>".}
proc mtcp_setconf(conf: ptr mtcp_conf): cint {.cdecl, importc: "mtcp_setconf",
    header: "<mtcp_api.h>".}
proc mtcp_core_affinitize(cpu: cint): cint {.cdecl, importc: "mtcp_core_affinitize",
    header: "<mtcp_api.h>".}
proc mtcp_create_context(cpu: cint): mctx_t {.cdecl, importc: "mtcp_create_context",
    header: "<mtcp_api.h>".}
proc mtcp_destroy_context(mctx: mctx_t) {.cdecl, importc: "mtcp_destroy_context",
                                        header: "<mtcp_api.h>".}
type
  mtcp_sighandler_t = proc (a2: cint) {.cdecl.}

proc mtcp_register_signal(signum: cint; handler: mtcp_sighandler_t): mtcp_sighandler_t {.
    cdecl, importc: "mtcp_register_signal", header: "<mtcp_api.h>".}

proc mtcp_pipe(mctx: mctx_t; pipeid: array[2, cint]): cint {.cdecl,
    importc: "mtcp_pipe", header: "<mtcp_api.h>".}

proc mtcp_init_rss(mctx: mctx_t; saddr_base: uint32; num_addr: cint;
                    daddr: uint32; dport: uint32): cint {.cdecl,
    importc: "mtcp_init_rss", header: "<mtcp_api.h>".}

proc initMtcp*(config: string) =
  checkZero "mtcp_init", mtcp_init(config)

proc initThreadLoopMtcp*(core: int) =
  initThreadLoopMtcpImpl(core=core)
