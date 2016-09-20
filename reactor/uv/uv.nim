import reactor/uv/errno
import reactor/uv/build

when defined(windows):
  type uv_buf_t* = object
    len*: int
    base*: pointer

  import winlean
  const SockAddr_maxsize* = 512
  export SockAddr_in, SockAddr, AddrInfo
else:
  type uv_buf_t* = object
    base*: pointer
    len*: int

  import posix
  const SockAddr_maxsize* = 512
  export SockAddr_in, SockAddr, AddrInfo
  export O_TRUNC, O_WRONLY, O_APPEND, O_RDONLY, O_RDWR

  # enums
type
  uv_handle_type_arg = cint
  uv_req_type_arg = cint

type # TODO
  uv_os_sock_t = cint
  uv_os_fd_t = cint
  uv_file = cint

  uv_lib_t = object
    handle: pointer
    errmsg: cstring

  # FIXME
  uv_uid_t = cint
  uv_gid_t = cint

type
  uv_mutex_t = pointer
  uv_rwlock_t = pointer
  uv_sem_t = pointer
  uv_cond_t = pointer
  uv_barrier_t = pointer
  uv_once_t = pointer
  uv_key_t = pointer
  uv_thread_t = pointer

type
  uv_fs_type* = enum
    UV_FS_UNKNOWN = - 1, UV_FS_CUSTOM, UV_FS_OPEN, UV_FS_CLOSE, UV_FS_READ,
    UV_FS_WRITE, UV_FS_SENDFILE, UV_FS_STAT, UV_FS_LSTAT, UV_FS_FSTAT,
    UV_FS_FTRUNCATE, UV_FS_UTIME, UV_FS_FUTIME, UV_FS_ACCESS, UV_FS_CHMOD,
    UV_FS_FCHMOD, UV_FS_FSYNC, UV_FS_FDATASYNC, UV_FS_UNLINK, UV_FS_RMDIR,
    UV_FS_MKDIR, UV_FS_MKDTEMP, UV_FS_RENAME, UV_FS_SCANDIR, UV_FS_LINK,
    UV_FS_SYMLINK, UV_FS_READLINK, UV_FS_CHOWN, UV_FS_FCHOWN, UV_FS_REALPATH

type
  uv_fs_s* = object
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    fs_type*: uv_fs_type
    loop*: ptr uv_loop_t
    cb*: uv_fs_cb
    result*: int
    `ptr`*: pointer
    path*: cstring
    statbuf*: uv_stat_t

  uv_connect_s* = object
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    cb*: uv_connect_cb
    handle*: ptr uv_stream_t

  uv_udp_flags* = enum
    UV_UDP_IPV6ONLY = 1, UV_UDP_PARTIAL = 2, UV_UDP_REUSEADDR = 4

  uv_errno_t* = cint

  uv_handle_type* = enum
    UV_UNKNOWN_HANDLE = 0, UV_ASYNC, UV_CHECK, UV_FS_EVENT, UV_FS_POLL, 
    UV_HANDLE, UV_IDLE, UV_NAMED_PIPE, UV_POLL, UV_PREPARE, UV_PROCESS, 
    UV_STREAM, UV_TCP, UV_TIMER, UV_TTY, UV_UDP, UV_SIGNAL, UV_FILE, 
    UV_HANDLE_TYPE_ARG_MAX
  uv_req_type* = enum
    UV_UNKNOWN_REQ = 0, UV_REQ, UV_CONNECT, UV_WRITE, UV_SHUTDOWN, UV_UDP_SEND, 
    UV_FS, UV_WORK, UV_GETADDRINFO, UV_GETNAMEINFO, UV_REQ_TYPE_ARG_MAX
  uv_loop_t* = pointer
  uv_handle_t* = object
    data*: pointer
  uv_stream_t* = uv_handle_t
  uv_tcp_t* = uv_handle_t
  uv_udp_t* = uv_handle_t
  uv_pipe_t* = pointer
  uv_tty_t* = pointer
  uv_poll_t* = uv_handle_t
  uv_timer_t* = uv_handle_t
  uv_prepare_t* = pointer
  uv_check_t* = pointer
  uv_idle_t* = uv_handle_t
  uv_async_t* = uv_handle_t
  uv_process_t* = uv_handle_t
  uv_fs_event_t* = pointer
  uv_fs_poll_t* = pointer
  uv_signal_t* = pointer
  uv_req_t* = object
    data*: pointer
    `type`*: uv_req_type_arg
  uv_getaddrinfo_t* = uv_req_t
  uv_getnameinfo_t* = uv_req_t
  uv_shutdown_t* = uv_req_t
  uv_write_t* = uv_req_t
  uv_connect_t* = uv_connect_s
  uv_udp_send_t* = uv_req_t
  uv_fs_t* = uv_fs_s
  uv_work_t* = pointer
  uv_cpu_info_t* = pointer
  uv_interface_address_t* = pointer
  uv_dirent_t*  = pointer
  uv_loop_option* = enum 
    UV_LOOP_BLOCK_SIGNAL
  uv_run_mode* = enum 
    UV_RUN_DEFAULT = 0, UV_RUN_ONCE, UV_RUN_NOWAIT

  uv_alloc_cb* = proc (handle: ptr uv_handle_t; suggested_size: csize;
                       buf: ptr uv_buf_t) {.cdecl.}
  uv_read_cb* = proc (stream: ptr uv_stream_t; nread: int; buf: ptr uv_buf_t) {.cdecl.}
  uv_write_cb* = proc (req: ptr uv_write_t; status: cint) {.cdecl.}
  uv_connect_cb* = proc (req: ptr uv_connect_t; status: cint) {.cdecl.}
  uv_shutdown_cb* = proc (req: ptr uv_shutdown_t; status: cint) {.cdecl.}
  uv_connection_cb* = proc (server: ptr uv_stream_t; status: cint) {.cdecl.}
  uv_close_cb* = proc (handle: ptr uv_handle_t) {.cdecl.}
  uv_poll_cb* = proc (handle: ptr uv_poll_t; status: cint; events: cint) {.cdecl.}
  uv_timer_cb* = proc (handle: ptr uv_timer_t) {.cdecl.}
  uv_async_cb* = proc (handle: ptr uv_async_t) {.cdecl.}
  uv_prepare_cb* = proc (handle: ptr uv_prepare_t) {.cdecl.}
  uv_check_cb* = proc (handle: ptr uv_check_t) {.cdecl.}
  uv_idle_cb* = proc (handle: ptr uv_idle_t) {.cdecl.}
  uv_exit_cb* = proc (a2: ptr uv_process_t; exit_status: int64;
                      term_signal: cint) {.cdecl.}
  uv_walk_cb* = proc (handle: ptr uv_handle_t; arg: pointer) {.cdecl.}
  uv_fs_cb* = proc (req: ptr uv_fs_t) {.cdecl.}
  uv_work_cb* = proc (req: ptr uv_work_t) {.cdecl.}
  uv_after_work_cb* = proc (req: ptr uv_work_t; status: cint) {.cdecl.}
  uv_getaddrinfo_cb* = proc (req: ptr uv_getaddrinfo_t; status: cint;
                             res: ptr AddrInfo) {.cdecl.}
  uv_getnameinfo_cb* = proc (req: ptr uv_getnameinfo_t; status: cint;
                             hostname: cstring; service: cstring) {.cdecl.}
  uv_timespec_t* = object 
    tv_sec*: clong
    tv_nsec*: clong

  uv_stat_t* = object 
    st_dev*: uint64
    st_mode*: uint64
    st_nlink*: uint64
    st_uid*: uint64
    st_gid*: uint64
    st_rdev*: uint64
    st_ino*: uint64
    st_size*: uint64
    st_blksize*: uint64
    st_blocks*: uint64
    st_flags*: uint64
    st_gen*: uint64
    st_atim*: uv_timespec_t
    st_mtim*: uv_timespec_t
    st_ctim*: uv_timespec_t
    st_birthtim*: uv_timespec_t

  uv_fs_event_cb* = proc (handle: ptr uv_fs_event_t; filename: cstring; 
                          events: cint; status: cint) {.cdecl.}
  uv_fs_poll_cb* = proc (handle: ptr uv_fs_poll_t; status: cint; 
                         prev: ptr uv_stat_t; curr: ptr uv_stat_t) {.cdecl.}
  uv_signal_cb* = proc (handle: ptr uv_signal_t; signum: cint) {.cdecl.}
  uv_membership* = enum 
    UV_LEAVE_GROUP = 0, UV_JOIN_GROUP

converter toCint*(a: uv_req_type): cint =
  return a.cint

converter toCint*(a: uv_handle_type): cint =
  return a.cint

proc uv_version*(): cuint {.importc.}
proc uv_version_string*(): cstring {.importc.}
type
  uv_malloc_func* = proc (size: csize): pointer {.cdecl.}
  uv_realloc_func* = proc (`ptr`: pointer; size: csize): pointer {.cdecl.}
  uv_calloc_func* = proc (count: csize; size: csize): pointer {.cdecl.}
  uv_free_func* = proc (`ptr`: pointer) {.cdecl.}

proc uv_replace_allocator*(malloc_func: uv_malloc_func;
                           realloc_func: uv_realloc_func;
                           calloc_func: uv_calloc_func; free_func: uv_free_func): cint {.importc.}
proc uv_default_loop*(): ptr uv_loop_t {.importc.}
proc uv_loop_init*(loop: ptr uv_loop_t): cint {.importc.}
proc uv_loop_close*(loop: ptr uv_loop_t): cint {.importc.}
proc uv_loop_new*(): ptr uv_loop_t {.importc.}
proc uv_loop_delete*(a2: ptr uv_loop_t) {.importc.}
proc uv_loop_size*(): csize {.importc.}
proc uv_loop_alive*(loop: ptr uv_loop_t): cint {.importc.}
proc uv_loop_configure*(loop: ptr uv_loop_t; option: uv_loop_option): cint {.varargs, importc.}
proc uv_run*(a2: ptr uv_loop_t; mode: uv_run_mode): cint {.importc.}
proc uv_stop*(a2: ptr uv_loop_t) {.importc.}
proc uv_ref*(a2: ptr uv_handle_t) {.importc.}
proc uv_unref*(a2: ptr uv_handle_t) {.importc.}
proc uv_has_ref*(a2: ptr uv_handle_t): cint {.importc.}
proc uv_update_time*(a2: ptr uv_loop_t) {.importc.}
proc uv_now*(a2: ptr uv_loop_t): uint64 {.importc.}
proc uv_backend_fd*(a2: ptr uv_loop_t): cint {.importc.}
proc uv_backend_timeout*(a2: ptr uv_loop_t): cint {.importc.}


proc uv_strerror*(err: cint): cstring {.importc.}
proc uv_err_name*(err: cint): cstring {.importc.}
type 
  uv_req_s* = object 
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]


proc uv_shutdown*(req: ptr uv_shutdown_t; handle: ptr uv_stream_t; 
                  cb: uv_shutdown_cb): cint {.importc.}
type 
  uv_shutdown_s* = object 
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    handle*: ptr uv_stream_t
    cb*: uv_shutdown_cb

  INNER_C_UNION_10507731583701144255* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_handle_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_10507731583701144255


proc uv_handle_size*(`type`: uv_handle_type_arg): csize {.importc.}
proc uv_req_size*(`type`: uv_req_type_arg): csize {.importc.}
proc uv_is_active*(handle: ptr uv_handle_t): cint {.importc.}
proc uv_walk*(loop: ptr uv_loop_t; walk_cb: uv_walk_cb; arg: pointer) {.importc.}
proc uv_print_all_handles*(loop: ptr uv_loop_t; stream: ptr FILE) {.importc.}
proc uv_print_active_handles*(loop: ptr uv_loop_t; stream: ptr FILE) {.importc.}
proc uv_close*(handle: ptr uv_handle_t; close_cb: uv_close_cb) {.importc.}
proc uv_send_buffer_size*(handle: ptr uv_handle_t; value: ptr cint): cint {.importc.}
proc uv_recv_buffer_size*(handle: ptr uv_handle_t; value: ptr cint): cint {.importc.}
proc uv_fileno*(handle: ptr uv_handle_t; fd: ptr uv_os_fd_t): cint {.importc.}
proc uv_buf_init*(base: cstring; len: cuint): uv_buf_t {.importc.}
type 
  INNER_C_UNION_6590849012234410065* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_stream_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_6590849012234410065
    write_queue_size*: csize
    alloc_cb*: uv_alloc_cb
    read_cb*: uv_read_cb


proc uv_listen*(stream: ptr uv_stream_t; backlog: cint; cb: uv_connection_cb): cint {.importc.}
proc uv_accept*(server: ptr uv_stream_t; client: ptr uv_stream_t): cint {.importc.}
proc uv_read_start*(a2: ptr uv_stream_t; alloc_cb: uv_alloc_cb; 
                    read_cb: uv_read_cb): cint {.importc.}
proc uv_read_stop*(a2: ptr uv_stream_t): cint {.importc.}
proc uv_write*(req: ptr uv_write_t; handle: ptr uv_stream_t; bufs: ptr uv_buf_t; 
               nbufs: cuint; cb: uv_write_cb): cint {.importc.}
proc uv_write2*(req: ptr uv_write_t; handle: ptr uv_stream_t; 
                bufs: ptr uv_buf_t; nbufs: cuint; send_handle: ptr uv_stream_t; 
                cb: uv_write_cb): cint {.importc.}
proc uv_try_write*(handle: ptr uv_stream_t; bufs: ptr uv_buf_t; nbufs: cuint): cint {.importc.}
type 
  uv_write_s* = object 
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    cb*: uv_write_cb
    send_handle*: ptr uv_stream_t
    handle*: ptr uv_stream_t


proc uv_is_readable*(handle: ptr uv_stream_t): cint {.importc.}
proc uv_is_writable*(handle: ptr uv_stream_t): cint {.importc.}
proc uv_stream_set_blocking*(handle: ptr uv_stream_t; blocking: cint): cint {.importc.}
proc uv_is_closing*(handle: ptr uv_handle_t): cint {.importc.}
type 
  INNER_C_UNION_3596046416482611825* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_tcp_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_3596046416482611825
    write_queue_size*: csize
    alloc_cb*: uv_alloc_cb
    read_cb*: uv_read_cb


proc uv_tcp_init*(a2: ptr uv_loop_t; handle: ptr uv_tcp_t): cint {.importc.}
proc uv_tcp_init_ex*(a2: ptr uv_loop_t; handle: ptr uv_tcp_t; flags: cuint): cint {.importc.}
proc uv_tcp_open*(handle: ptr uv_tcp_t; sock: uv_os_sock_t): cint {.importc.}
proc uv_tcp_nodelay*(handle: ptr uv_tcp_t; enable: cint): cint {.importc.}
proc uv_tcp_keepalive*(handle: ptr uv_tcp_t; enable: cint; delay: cuint): cint {.importc.}
proc uv_tcp_simultaneous_accepts*(handle: ptr uv_tcp_t; enable: cint): cint {.importc.}
type 
  uv_tcp_flags* = enum 
    UV_TCP_IPV6ONLY = 1


proc uv_tcp_bind*(handle: ptr uv_tcp_t; `addr`: ptr SockAddr; flags: cuint): cint {.importc.}
proc uv_tcp_getsockname*(handle: ptr uv_tcp_t; name: ptr SockAddr;
                         namelen: ptr cint): cint {.importc.}
proc uv_tcp_getpeername*(handle: ptr uv_tcp_t; name: ptr SockAddr;
                         namelen: ptr cint): cint {.importc.}
proc uv_tcp_connect*(req: ptr uv_connect_t; handle: ptr uv_tcp_t; 
                     `addr`: ptr SockAddr; cb: uv_connect_cb): cint {.importc.}

type 
  uv_udp_send_cb* = proc (req: ptr uv_udp_send_t; status: cint) {.cdecl.}
  uv_udp_recv_cb* = proc (handle: ptr uv_udp_t; nread: int;
                          buf: ptr uv_buf_t; `addr`: ptr SockAddr; flags: cuint) {.cdecl.}
  INNER_C_UNION_5221779730467212091* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_udp_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_5221779730467212091
    send_queue_size*: csize
    send_queue_count*: csize

  uv_udp_send_s* = object 
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    handle*: ptr uv_udp_t
    cb*: uv_udp_send_cb


proc uv_udp_init*(a2: ptr uv_loop_t; handle: ptr uv_udp_t): cint {.importc.}
proc uv_udp_init_ex*(a2: ptr uv_loop_t; handle: ptr uv_udp_t; flags: cuint): cint {.importc.}
proc uv_udp_open*(handle: ptr uv_udp_t; sock: uv_os_sock_t): cint {.importc.}
proc uv_udp_bind*(handle: ptr uv_udp_t; `addr`: ptr SockAddr; flags: cuint): cint {.importc.}
proc uv_udp_getsockname*(handle: ptr uv_udp_t; name: ptr SockAddr;
                         namelen: ptr cint): cint {.importc.}
proc uv_udp_set_membership*(handle: ptr uv_udp_t; multicast_addr: cstring; 
                            interface_addr: cstring; membership: uv_membership): cint {.importc.}
proc uv_udp_set_multicast_loop*(handle: ptr uv_udp_t; on: cint): cint {.importc.}
proc uv_udp_set_multicast_ttl*(handle: ptr uv_udp_t; ttl: cint): cint {.importc.}
proc uv_udp_set_multicast_interface*(handle: ptr uv_udp_t; 
                                     interface_addr: cstring): cint {.importc.}
proc uv_udp_set_broadcast*(handle: ptr uv_udp_t; on: cint): cint {.importc.}
proc uv_udp_set_ttl*(handle: ptr uv_udp_t; ttl: cint): cint {.importc.}
proc uv_udp_send*(req: ptr uv_udp_send_t; handle: ptr uv_udp_t; 
                  bufs: ptr uv_buf_t; nbufs: cuint; `addr`: ptr SockAddr;
                  send_cb: uv_udp_send_cb): cint {.importc.}
proc uv_udp_try_send*(handle: ptr uv_udp_t; bufs: ptr uv_buf_t; nbufs: cuint; 
                      `addr`: ptr SockAddr): cint {.importc.}
proc uv_udp_recv_start*(handle: ptr uv_udp_t; alloc_cb: uv_alloc_cb; 
                        recv_cb: uv_udp_recv_cb): cint {.importc.}
proc uv_udp_recv_stop*(handle: ptr uv_udp_t): cint {.importc.}
type 
  INNER_C_UNION_5845044092622324401* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_tty_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_5845044092622324401
    write_queue_size*: csize
    alloc_cb*: uv_alloc_cb
    read_cb*: uv_read_cb

  uv_tty_mode_t* = enum 
    UV_TTY_MODE_NORMAL, UV_TTY_MODE_RAW, UV_TTY_MODE_IO


proc uv_tty_init*(a2: ptr uv_loop_t; a3: ptr uv_tty_t; fd: uv_file; 
                  readable: cint): cint {.importc.}
proc uv_tty_set_mode*(a2: ptr uv_tty_t; mode: uv_tty_mode_t): cint {.importc.}
proc uv_tty_reset_mode*(): cint {.importc.}
proc uv_tty_get_winsize*(a2: ptr uv_tty_t; width: ptr cint; height: ptr cint): cint {.importc.}
proc uv_guess_handle*(file: uv_file): uv_handle_type_arg {.importc.}
type 
  INNER_C_UNION_16028222375510153848* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_pipe_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_16028222375510153848
    write_queue_size*: csize
    alloc_cb*: uv_alloc_cb
    read_cb*: uv_read_cb
    ipc*: cint


proc uv_pipe_init*(a2: ptr uv_loop_t; handle: ptr uv_pipe_t; ipc: cint): cint {.importc.}
proc uv_pipe_open*(a2: ptr uv_pipe_t; file: uv_file): cint {.importc.}
proc uv_pipe_bind*(handle: ptr uv_pipe_t; name: cstring): cint {.importc.}
proc uv_pipe_connect*(req: ptr uv_connect_t; handle: ptr uv_pipe_t; 
                      name: cstring; cb: uv_connect_cb) {.importc.}
proc uv_pipe_getsockname*(handle: ptr uv_pipe_t; buffer: cstring; 
                          size: ptr csize): cint {.importc.}
proc uv_pipe_getpeername*(handle: ptr uv_pipe_t; buffer: cstring; 
                          size: ptr csize): cint {.importc.}
proc uv_pipe_pending_instances*(handle: ptr uv_pipe_t; count: cint) {.importc.}
proc uv_pipe_pending_count*(handle: ptr uv_pipe_t): cint {.importc.}
proc uv_pipe_pending_type*(handle: ptr uv_pipe_t): uv_handle_type_arg {.importc.}
type 
  INNER_C_UNION_10983300994003237821* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_poll_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_10983300994003237821
    poll_cb*: uv_poll_cb

  uv_poll_event* = enum 
    UV_READABLE = 1, UV_WRITABLE = 2


proc uv_poll_init*(loop: ptr uv_loop_t; handle: ptr uv_poll_t; fd: cint): cint {.importc.}
proc uv_poll_init_socket*(loop: ptr uv_loop_t; handle: ptr uv_poll_t; 
                          socket: uv_os_sock_t): cint {.importc.}
proc uv_poll_start*(handle: ptr uv_poll_t; events: cint; cb: uv_poll_cb): cint {.importc.}
proc uv_poll_stop*(handle: ptr uv_poll_t): cint {.importc.}
type 
  INNER_C_UNION_13797140684363503580* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_prepare_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_13797140684363503580


proc uv_prepare_init*(a2: ptr uv_loop_t; prepare: ptr uv_prepare_t): cint {.importc.}
proc uv_prepare_start*(prepare: ptr uv_prepare_t; cb: uv_prepare_cb): cint {.importc.}
proc uv_prepare_stop*(prepare: ptr uv_prepare_t): cint {.importc.}
type 
  INNER_C_UNION_16814348499152137992* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_check_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_16814348499152137992


proc uv_check_init*(a2: ptr uv_loop_t; check: ptr uv_check_t): cint {.importc.}
proc uv_check_start*(check: ptr uv_check_t; cb: uv_check_cb): cint {.importc.}
proc uv_check_stop*(check: ptr uv_check_t): cint {.importc.}
type 
  INNER_C_UNION_12680267433943841815* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_idle_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_12680267433943841815


proc uv_idle_init*(a2: ptr uv_loop_t; idle: ptr uv_idle_t): cint {.importc.}
proc uv_idle_start*(idle: ptr uv_idle_t; cb: uv_idle_cb): cint {.importc.}
proc uv_idle_stop*(idle: ptr uv_idle_t): cint {.importc.}
type 
  INNER_C_UNION_9047668530012837112* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_async_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_9047668530012837112


proc uv_async_init*(a2: ptr uv_loop_t; async: ptr uv_async_t; 
                    async_cb: uv_async_cb): cint {.importc.}
proc uv_async_send*(async: ptr uv_async_t): cint {.importc.}
type 
  INNER_C_UNION_9416403630688343926* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_timer_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_9416403630688343926


proc uv_timer_init*(a2: ptr uv_loop_t; handle: ptr uv_timer_t): cint {.importc.}
proc uv_timer_start*(handle: ptr uv_timer_t; cb: uv_timer_cb; timeout: uint64;
                     repeat: uint64): cint {.importc.}
proc uv_timer_stop*(handle: ptr uv_timer_t): cint {.importc.}
proc uv_timer_again*(handle: ptr uv_timer_t): cint {.importc.}
proc uv_timer_set_repeat*(handle: ptr uv_timer_t; repeat: uint64) {.importc.}
proc uv_timer_get_repeat*(handle: ptr uv_timer_t): uint64 {.importc.}
type 
  uv_getaddrinfo_s* = object
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    loop*: ptr uv_loop_t


proc uv_getaddrinfo*(loop: ptr uv_loop_t; req: ptr uv_getaddrinfo_t;
                     getAddrInfo_cb: uv_getAddrInfo_cb; node: cstring;
                     service: cstring; hints: ptr AddrInfo): cint {.importc.}
proc uv_freeaddrinfo*(ai: ptr AddrInfo) {.importc.}
type 
  uv_getnameinfo_s* = object 
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    loop*: ptr uv_loop_t


proc uv_getnameinfo*(loop: ptr uv_loop_t; req: ptr uv_getnameinfo_t; 
                     getnameinfo_cb: uv_getnameinfo_cb; `addr`: ptr SockAddr;
                     flags: cint): cint {.importc.}
type 
  INNER_C_UNION_16012582286293367729* = object  {.union.}
    stream*: ptr uv_stream_t
    fd*: cint

  uv_stdio_flags* = enum 
    UV_IGNORE = 0x00000000, UV_CREATE_PIPE = 0x00000001, 
    UV_INHERIT_FD = 0x00000002, UV_INHERIT_STREAM = 0x00000004, 
    UV_READABLE_PIPE = 0x00000010, UV_WRITABLE_PIPE = 0x00000020
  uv_stdio_container_t* = object 
    flags*: uv_stdio_flags
    data*: INNER_C_UNION_16012582286293367729

  uv_process_options_t* = object 
    exit_cb*: uv_exit_cb
    file*: cstring
    args*: cstringArray
    env*: cstringArray
    cwd*: cstring
    flags*: cuint
    stdio_count*: cint
    stdio*: ptr uv_stdio_container_t
    uid*: uv_uid_t
    gid*: uv_gid_t



type 
  uv_process_flags* = enum 
    UV_PROCESS_SETUID = (1 shl 0), UV_PROCESS_SETGID = (1 shl 1), 
    UV_PROCESS_WINDOWS_VERBATIM_ARGUMENTS = (1 shl 2), 
    UV_PROCESS_DETACHED = (1 shl 3), UV_PROCESS_WINDOWS_HIDE = (1 shl 4)


type 
  INNER_C_UNION_11845354711802889067* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_process_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_11845354711802889067
    exit_cb*: uv_exit_cb
    pid*: cint


proc uv_spawn*(loop: ptr uv_loop_t; handle: ptr uv_process_t; 
               options: ptr uv_process_options_t): cint {.importc.}
proc uv_process_kill*(a2: ptr uv_process_t; signum: cint): cint {.importc.}
proc uv_kill*(pid: cint; signum: cint): cint {.importc.}
type 
  uv_work_s* = object 
    data*: pointer
    `type`*: uv_req_type_arg
    active_queue*: array[2, pointer]
    reserved*: array[4, pointer]
    loop*: ptr uv_loop_t
    work_cb*: uv_work_cb
    after_work_cb*: uv_after_work_cb


proc uv_queue_work*(loop: ptr uv_loop_t; req: ptr uv_work_t; 
                    work_cb: uv_work_cb; after_work_cb: uv_after_work_cb): cint {.importc.}
proc uv_cancel*(req: ptr uv_req_t): cint {.importc.}
type 
  uv_cpu_times_s_8938141823436824889* = object 
    user*: uint64
    nice*: uint64
    sys*: uint64
    idle*: uint64
    irq*: uint64

  uv_cpu_info_s* = object 
    model*: cstring
    speed*: cint
    cpu_times*: uv_cpu_times_s_8938141823436824889

  INNER_C_UNION_9228501422869894510* = object  {.union.}
    address4*: SockAddr_in
    address6*: SockAddr_in6

  INNER_C_UNION_3272308776972020633* = object  {.union.}
    netmask4*: SockAddr_in
    netmask6*: SockAddr_in6

  uv_interface_address_s* = object 
    name*: cstring
    phys_addr*: array[6, char]
    is_internal*: cint
    address*: INNER_C_UNION_9228501422869894510
    netmask*: INNER_C_UNION_3272308776972020633

  uv_dirent_type_t* = enum 
    UV_DIRENT_UNKNOWN, UV_DIRENT_FILE, UV_DIRENT_DIR, UV_DIRENT_LINK, 
    UV_DIRENT_FIFO, UV_DIRENT_SOCKET, UV_DIRENT_CHAR, UV_DIRENT_BLOCK


type 
  uv_dirent_s* = object 
    name*: cstring
    `type`*: uv_dirent_type_t


proc uv_setup_args*(argc: cint; argv: cstringArray): cstringArray {.importc.}
proc uv_get_process_title*(buffer: cstring; size: csize): cint {.importc.}
proc uv_set_process_title*(title: cstring): cint {.importc.}
proc uv_resident_set_memory*(rss: ptr csize): cint {.importc.}
proc uv_uptime*(uptime: ptr cdouble): cint {.importc.}
type 
  uv_timeval_t* = object 
    tv_sec*: clong
    tv_usec*: clong

  uv_rusage_t* = object 
    ru_utime*: uv_timeval_t
    ru_stime*: uv_timeval_t
    ru_maxrss*: uint64
    ru_ixrss*: uint64
    ru_idrss*: uint64
    ru_isrss*: uint64
    ru_minflt*: uint64
    ru_majflt*: uint64
    ru_nswap*: uint64
    ru_inblock*: uint64
    ru_oublock*: uint64
    ru_msgsnd*: uint64
    ru_msgrcv*: uint64
    ru_nsignals*: uint64
    ru_nvcsw*: uint64
    ru_nivcsw*: uint64


proc uv_getrusage*(rusage: ptr uv_rusage_t): cint {.importc.}
proc uv_os_homedir*(buffer: cstring; size: ptr csize): cint {.importc.}
proc uv_cpu_info*(cpu_infos: ptr ptr uv_cpu_info_t; count: ptr cint): cint {.importc.}
proc uv_free_cpu_info*(cpu_infos: ptr uv_cpu_info_t; count: cint) {.importc.}
proc uv_interface_addresses*(addresses: ptr ptr uv_interface_address_t; 
                             count: ptr cint): cint {.importc.}
proc uv_free_interface_addresses*(addresses: ptr uv_interface_address_t; 
                                  count: cint) {.importc.}

proc uv_fs_req_cleanup*(req: ptr uv_fs_t) {.importc.}
proc uv_fs_close*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                  cb: uv_fs_cb): cint {.importc.}
proc uv_fs_open*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                 flags: cint; mode: cint; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_read*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                 bufs: ptr uv_buf_t; nbufs: cuint; offset: int64; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_unlink*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                   cb: uv_fs_cb): cint {.importc.}
proc uv_fs_write*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                  bufs: ptr uv_buf_t; nbufs: cuint; offset: int64;
                  cb: uv_fs_cb): cint {.importc.}
proc uv_fs_mkdir*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                  mode: cint; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_mkdtemp*(loop: ptr uv_loop_t; req: ptr uv_fs_t; tpl: cstring; 
                    cb: uv_fs_cb): cint {.importc.}
proc uv_fs_rmdir*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                  cb: uv_fs_cb): cint {.importc.}
proc uv_fs_scandir*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                    flags: cint; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_scandir_next*(req: ptr uv_fs_t; ent: ptr uv_dirent_t): cint {.importc.}
proc uv_fs_stat*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                 cb: uv_fs_cb): cint {.importc.}
proc uv_fs_fstat*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                  cb: uv_fs_cb): cint {.importc.}
proc uv_fs_rename*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                   new_path: cstring; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_fsync*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                  cb: uv_fs_cb): cint {.importc.}
proc uv_fs_fdatasync*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                      cb: uv_fs_cb): cint {.importc.}
proc uv_fs_ftruncate*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                      offset: int64; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_sendfile*(loop: ptr uv_loop_t; req: ptr uv_fs_t; out_fd: uv_file; 
                     in_fd: uv_file; in_offset: int64; length: csize;
                     cb: uv_fs_cb): cint {.importc.}
proc uv_fs_access*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                   mode: cint; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_chmod*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                  mode: cint; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_utime*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                  atime: cdouble; mtime: cdouble; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_futime*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                   atime: cdouble; mtime: cdouble; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_lstat*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                  cb: uv_fs_cb): cint {.importc.}
proc uv_fs_link*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                 new_path: cstring; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_symlink*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                    new_path: cstring; flags: cint; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_readlink*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                     cb: uv_fs_cb): cint {.importc.}
proc uv_fs_realpath*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                     cb: uv_fs_cb): cint {.importc.}
proc uv_fs_fchmod*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                   mode: cint; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_chown*(loop: ptr uv_loop_t; req: ptr uv_fs_t; path: cstring; 
                  uid: uv_uid_t; gid: uv_gid_t; cb: uv_fs_cb): cint {.importc.}
proc uv_fs_fchown*(loop: ptr uv_loop_t; req: ptr uv_fs_t; file: uv_file; 
                   uid: uv_uid_t; gid: uv_gid_t; cb: uv_fs_cb): cint {.importc.}
type 
  uv_fs_event* = enum 
    UV_RENAME = 1, UV_CHANGE = 2


type 
  INNER_C_UNION_1939456371041102125* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_fs_event_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_1939456371041102125
    path*: cstring

  INNER_C_UNION_5427338491189710218* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_fs_poll_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_5427338491189710218
    poll_ctx*: pointer


proc uv_fs_poll_init*(loop: ptr uv_loop_t; handle: ptr uv_fs_poll_t): cint {.importc.}
proc uv_fs_poll_start*(handle: ptr uv_fs_poll_t; poll_cb: uv_fs_poll_cb; 
                       path: cstring; interval: cuint): cint {.importc.}
proc uv_fs_poll_stop*(handle: ptr uv_fs_poll_t): cint {.importc.}
proc uv_fs_poll_getpath*(handle: ptr uv_fs_poll_t; buffer: cstring; 
                         size: ptr csize): cint {.importc.}
type 
  INNER_C_UNION_11359569105578982015* = object  {.union.}
    fd*: cint
    reserved*: array[4, pointer]

  uv_signal_s* = object 
    data*: pointer
    loop*: ptr uv_loop_t
    `type`*: uv_handle_type_arg
    close_cb*: uv_close_cb
    handle_queue*: array[2, pointer]
    u*: INNER_C_UNION_11359569105578982015
    signal_cb*: uv_signal_cb
    signum*: cint


proc uv_signal_init*(loop: ptr uv_loop_t; handle: ptr uv_signal_t): cint {.importc.}
proc uv_signal_start*(handle: ptr uv_signal_t; signal_cb: uv_signal_cb; 
                      signum: cint): cint {.importc.}
proc uv_signal_stop*(handle: ptr uv_signal_t): cint {.importc.}
proc uv_loadavg*(avg: array[3, cdouble]) {.importc.}
type 
  uv_fs_event_flags* = enum 
    UV_FS_EVENT_WATCH_ENTRY = 1, UV_FS_EVENT_STAT = 2, UV_FS_EVENT_RECURSIVE = 4


proc uv_fs_event_init*(loop: ptr uv_loop_t; handle: ptr uv_fs_event_t): cint {.importc.}
proc uv_fs_event_start*(handle: ptr uv_fs_event_t; cb: uv_fs_event_cb; 
                        path: cstring; flags: cuint): cint {.importc.}
proc uv_fs_event_stop*(handle: ptr uv_fs_event_t): cint {.importc.}
proc uv_fs_event_getpath*(handle: ptr uv_fs_event_t; buffer: cstring; 
                          size: ptr csize): cint {.importc.}
proc uv_ip4_addr*(ip: cstring; port: cint; `addr`: ptr SockAddr_in): cint {.importc.}
proc uv_ip6_addr*(ip: cstring; port: cint; `addr`: ptr SockAddr_in6): cint {.importc.}
proc uv_ip4_name*(src: ptr SockAddr_in; dst: cstring; size: csize): cint {.importc.}
proc uv_ip6_name*(src: ptr SockAddr_in6; dst: cstring; size: csize): cint {.importc.}
proc uv_inet_ntop*(af: cint; src: pointer; dst: cstring; size: csize): cint {.importc.}
proc uv_inet_pton*(af: cint; src: cstring; dst: pointer): cint {.importc.}
proc uv_exepath*(buffer: cstring; size: ptr csize): cint {.importc.}
proc uv_cwd*(buffer: cstring; size: ptr csize): cint {.importc.}
proc uv_chdir*(dir: cstring): cint {.importc.}
proc uv_get_free_memory*(): uint64 {.importc.}
proc uv_get_total_memory*(): uint64 {.importc.}
proc uv_hrtime*(): uint64 {.importc.}
proc uv_disable_stdio_inheritance*() {.importc.}
proc uv_dlopen*(filename: cstring; lib: ptr uv_lib_t): cint {.importc.}
proc uv_dlclose*(lib: ptr uv_lib_t) {.importc.}
proc uv_dlsym*(lib: ptr uv_lib_t; name: cstring; `ptr`: ptr pointer): cint {.importc.}
proc uv_dlerror*(lib: ptr uv_lib_t): cstring {.importc.}
proc uv_mutex_init*(handle: ptr uv_mutex_t): cint {.importc.}
proc uv_mutex_destroy*(handle: ptr uv_mutex_t) {.importc.}
proc uv_mutex_lock*(handle: ptr uv_mutex_t) {.importc.}
proc uv_mutex_trylock*(handle: ptr uv_mutex_t): cint {.importc.}
proc uv_mutex_unlock*(handle: ptr uv_mutex_t) {.importc.}
proc uv_rwlock_init*(rwlock: ptr uv_rwlock_t): cint {.importc.}
proc uv_rwlock_destroy*(rwlock: ptr uv_rwlock_t) {.importc.}
proc uv_rwlock_rdlock*(rwlock: ptr uv_rwlock_t) {.importc.}
proc uv_rwlock_tryrdlock*(rwlock: ptr uv_rwlock_t): cint {.importc.}
proc uv_rwlock_rdunlock*(rwlock: ptr uv_rwlock_t) {.importc.}
proc uv_rwlock_wrlock*(rwlock: ptr uv_rwlock_t) {.importc.}
proc uv_rwlock_trywrlock*(rwlock: ptr uv_rwlock_t): cint {.importc.}
proc uv_rwlock_wrunlock*(rwlock: ptr uv_rwlock_t) {.importc.}
proc uv_sem_init*(sem: ptr uv_sem_t; value: cuint): cint {.importc.}
proc uv_sem_destroy*(sem: ptr uv_sem_t) {.importc.}
proc uv_sem_post*(sem: ptr uv_sem_t) {.importc.}
proc uv_sem_wait*(sem: ptr uv_sem_t) {.importc.}
proc uv_sem_trywait*(sem: ptr uv_sem_t): cint {.importc.}
proc uv_cond_init*(cond: ptr uv_cond_t): cint {.importc.}
proc uv_cond_destroy*(cond: ptr uv_cond_t) {.importc.}
proc uv_cond_signal*(cond: ptr uv_cond_t) {.importc.}
proc uv_cond_broadcast*(cond: ptr uv_cond_t) {.importc.}
proc uv_barrier_init*(barrier: ptr uv_barrier_t; count: cuint): cint {.importc.}
proc uv_barrier_destroy*(barrier: ptr uv_barrier_t) {.importc.}
proc uv_barrier_wait*(barrier: ptr uv_barrier_t): cint {.importc.}
proc uv_cond_wait*(cond: ptr uv_cond_t; mutex: ptr uv_mutex_t) {.importc.}
proc uv_cond_timedwait*(cond: ptr uv_cond_t; mutex: ptr uv_mutex_t; 
                        timeout: uint64): cint {.importc.}
proc uv_once*(guard: ptr uv_once_t; callback: proc ()) {.importc.}
proc uv_key_create*(key: ptr uv_key_t): cint {.importc.}
proc uv_key_delete*(key: ptr uv_key_t) {.importc.}
proc uv_key_get*(key: ptr uv_key_t): pointer {.importc.}
proc uv_key_set*(key: ptr uv_key_t; value: pointer) {.importc.}
type 
  uv_thread_cb* = proc (arg: pointer)

proc uv_thread_create*(tid: ptr uv_thread_t; entry: uv_thread_cb; arg: pointer): cint {.importc.}
proc uv_thread_self*(): uv_thread_t {.importc.}
proc uv_thread_join*(tid: ptr uv_thread_t): cint {.importc.}
proc uv_thread_equal*(t1: ptr uv_thread_t; t2: ptr uv_thread_t): cint {.importc.}
type 
  uv_any_handle* = object  {.union.}
    async*: uv_async_t
    check*: uv_check_t
    fs_event*: uv_fs_event_t
    fs_poll*: uv_fs_poll_t
    handle*: uv_handle_t
    idle*: uv_idle_t
    pipe*: uv_pipe_t
    poll*: uv_poll_t
    prepare*: uv_prepare_t
    process*: uv_process_t
    stream*: uv_stream_t
    tcp*: uv_tcp_t
    timer*: uv_timer_t
    tty*: uv_tty_t
    udp*: uv_udp_t
    signal*: uv_signal_t

  uv_any_req* = object  {.union.}
    req*: uv_req_t
    connect*: uv_connect_t
    write*: uv_write_t
    shutdown*: uv_shutdown_t
    udp_send*: uv_udp_send_t
    fs*: uv_fs_t
    work*: uv_work_t
    getAddrInfo*: uv_getaddrinfo_t
    getnameinfo*: uv_getnameinfo_t

  uv_loop_s* = object 
    data*: pointer
    active_handles*: cuint
    handle_queue*: array[2, pointer]
    active_reqs*: array[2, pointer]
    stop_flag*: cuint
