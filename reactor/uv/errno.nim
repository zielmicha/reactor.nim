import posix

const 
  UV_EOF* = (- 4095)
  UV_UNKNOWN* = (- 4094)
  UV_EAI_ADDRFAMILY* = (- 3000)
  UV_EAI_AGAIN* = (- 3001)
  UV_EAI_BADFLAGS* = (- 3002)
  UV_EAI_CANCELED* = (- 3003)
  UV_EAI_FAIL* = (- 3004)
  UV_EAI_FAMILY* = (- 3005)
  UV_EAI_MEMORY* = (- 3006)
  UV_EAI_NODATA* = (- 3007)
  UV_EAI_NONAME* = (- 3008)
  UV_EAI_OVERFLOW* = (- 3009)
  UV_EAI_SERVICE* = (- 3010)
  UV_EAI_SOCKTYPE* = (- 3011)
  UV_EAI_BADHINTS* = (- 3013)
  UV_EAI_PROTOCOL* = (- 3014)

# Only map to the system errno on non-Windows platforms. It's apparently
#  a fairly common practice for Windows programmers to redefine errno codes.
# 

when defined(E2BIG) and not defined(windows):
  const 
    UV_E2BIG* = (- E2BIG)
else: 
  const 
    UV_E2BIG* = (- 4093)
when defined(EACCES) and not defined(windows):
  const 
    UV_EACCES* = (- EACCES)
else: 
  const 
    UV_EACCES* = (- 4092)
when defined(EADDRINUSE) and not defined(windows):
  const 
    UV_EADDRINUSE* = (- EADDRINUSE)
else: 
  const 
    UV_EADDRINUSE* = (- 4091)
when defined(EADDRNOTAVAIL) and not defined(windows):
  const 
    UV_EADDRNOTAVAIL* = (- EADDRNOTAVAIL)
else: 
  const 
    UV_EADDRNOTAVAIL* = (- 4090)
when defined(EAFNOSUPPORT) and not defined(windows):
  const 
    UV_EAFNOSUPPORT* = (- EAFNOSUPPORT)
else: 
  const 
    UV_EAFNOSUPPORT* = (- 4089)
when defined(EAGAIN) and not defined(windows):
  const 
    UV_EAGAIN* = (- EAGAIN)
else: 
  const 
    UV_EAGAIN* = (- 4088)
when defined(EALREADY) and not defined(windows):
  const 
    UV_EALREADY* = (- EALREADY)
else: 
  const 
    UV_EALREADY* = (- 4084)
when defined(EBADF) and not defined(windows):
  const 
    UV_EBADF* = (- EBADF)
else: 
  const 
    UV_EBADF* = (- 4083)
when defined(EBUSY) and not defined(windows):
  const 
    UV_EBUSY* = (- EBUSY)
else: 
  const 
    UV_EBUSY* = (- 4082)
when defined(ECANCELED) and not defined(windows):
  const 
    UV_ECANCELED* = (- ECANCELED)
else: 
  const 
    UV_ECANCELED* = (- 4081)
when defined(ECHARSET) and not defined(windows):
  const 
    UV_ECHARSET* = (- ECHARSET)
else: 
  const 
    UV_ECHARSET* = (- 4080)
when defined(ECONNABORTED) and not defined(windows):
  const 
    UV_ECONNABORTED* = (- ECONNABORTED)
else: 
  const 
    UV_ECONNABORTED* = (- 4079)
when defined(ECONNREFUSED) and not defined(windows):
  const 
    UV_ECONNREFUSED* = (- ECONNREFUSED)
else: 
  const 
    UV_ECONNREFUSED* = (- 4078)
when defined(ECONNRESET) and not defined(windows):
  const 
    UV_ECONNRESET* = (- ECONNRESET)
else: 
  const 
    UV_ECONNRESET* = (- 4077)
when defined(EDESTADDRREQ) and not defined(windows):
  const 
    UV_EDESTADDRREQ* = (- EDESTADDRREQ)
else: 
  const 
    UV_EDESTADDRREQ* = (- 4076)
when defined(EEXIST) and not defined(windows):
  const 
    UV_EEXIST* = (- EEXIST)
else: 
  const 
    UV_EEXIST* = (- 4075)
when defined(EFAULT) and not defined(windows):
  const 
    UV_EFAULT* = (- EFAULT)
else: 
  const 
    UV_EFAULT* = (- 4074)
when defined(EHOSTUNREACH) and not defined(windows):
  const 
    UV_EHOSTUNREACH* = (- EHOSTUNREACH)
else: 
  const 
    UV_EHOSTUNREACH* = (- 4073)
when defined(EINTR) and not defined(windows):
  const 
    UV_EINTR* = (- EINTR)
else: 
  const 
    UV_EINTR* = (- 4072)
when defined(EINVAL) and not defined(windows):
  const 
    UV_EINVAL* = (- EINVAL)
else: 
  const 
    UV_EINVAL* = (- 4071)
when defined(EIO) and not defined(windows):
  const 
    UV_EIO* = (- EIO)
else: 
  const 
    UV_EIO* = (- 4070)
when defined(EISCONN) and not defined(windows):
  const 
    UV_EISCONN* = (- EISCONN)
else: 
  const 
    UV_EISCONN* = (- 4069)
when defined(EISDIR) and not defined(windows):
  const 
    UV_EISDIR* = (- EISDIR)
else: 
  const 
    UV_EISDIR* = (- 4068)
when defined(ELOOP) and not defined(windows):
  const 
    UV_ELOOP* = (- ELOOP)
else: 
  const 
    UV_ELOOP* = (- 4067)
when defined(EMFILE) and not defined(windows):
  const 
    UV_EMFILE* = (- EMFILE)
else: 
  const 
    UV_EMFILE* = (- 4066)
when defined(EMSGSIZE) and not defined(windows):
  const 
    UV_EMSGSIZE* = (- EMSGSIZE)
else: 
  const 
    UV_EMSGSIZE* = (- 4065)
when defined(ENAMETOOLONG) and not defined(windows):
  const 
    UV_ENAMETOOLONG* = (- ENAMETOOLONG)
else: 
  const 
    UV_ENAMETOOLONG* = (- 4064)
when defined(ENETDOWN) and not defined(windows):
  const 
    UV_ENETDOWN* = (- ENETDOWN)
else: 
  const 
    UV_ENETDOWN* = (- 4063)
when defined(ENETUNREACH) and not defined(windows):
  const 
    UV_ENETUNREACH* = (- ENETUNREACH)
else: 
  const 
    UV_ENETUNREACH* = (- 4062)
when defined(ENFILE) and not defined(windows):
  const 
    UV_ENFILE* = (- ENFILE)
else: 
  const 
    UV_ENFILE* = (- 4061)
when defined(ENOBUFS) and not defined(windows):
  const 
    UV_ENOBUFS* = (- ENOBUFS)
else: 
  const 
    UV_ENOBUFS* = (- 4060)
when defined(ENODEV) and not defined(windows):
  const 
    UV_ENODEV* = (- ENODEV)
else: 
  const 
    UV_ENODEV* = (- 4059)
when defined(ENOENT) and not defined(windows):
  const 
    UV_ENOENT* = (- ENOENT)
else: 
  const 
    UV_ENOENT* = (- 4058)
when defined(ENOMEM) and not defined(windows):
  const 
    UV_ENOMEM* = (- ENOMEM)
else: 
  const 
    UV_ENOMEM* = (- 4057)
when defined(ENONET) and not defined(windows):
  const 
    UV_ENONET* = (- ENONET)
else: 
  const 
    UV_ENONET* = (- 4056)
when defined(ENOSPC) and not defined(windows):
  const 
    UV_ENOSPC* = (- ENOSPC)
else: 
  const 
    UV_ENOSPC* = (- 4055)
when defined(ENOSYS) and not defined(windows):
  const 
    UV_ENOSYS* = (- ENOSYS)
else: 
  const 
    UV_ENOSYS* = (- 4054)
when defined(ENOTCONN) and not defined(windows):
  const 
    UV_ENOTCONN* = (- ENOTCONN)
else: 
  const 
    UV_ENOTCONN* = (- 4053)
when defined(ENOTDIR) and not defined(windows):
  const 
    UV_ENOTDIR* = (- ENOTDIR)
else: 
  const 
    UV_ENOTDIR* = (- 4052)
when defined(ENOTEMPTY) and not defined(windows):
  const 
    UV_ENOTEMPTY* = (- ENOTEMPTY)
else: 
  const 
    UV_ENOTEMPTY* = (- 4051)
when defined(ENOTSOCK) and not defined(windows):
  const 
    UV_ENOTSOCK* = (- ENOTSOCK)
else: 
  const 
    UV_ENOTSOCK* = (- 4050)
when defined(ENOTSUP) and not defined(windows):
  const 
    UV_ENOTSUP* = (- ENOTSUP)
else: 
  const 
    UV_ENOTSUP* = (- 4049)
when defined(EPERM) and not defined(windows):
  const 
    UV_EPERM* = (- EPERM)
else: 
  const 
    UV_EPERM* = (- 4048)
when defined(EPIPE) and not defined(windows):
  const 
    UV_EPIPE* = (- EPIPE)
else: 
  const 
    UV_EPIPE* = (- 4047)
when defined(EPROTO) and not defined(windows):
  const 
    UV_EPROTO* = (- EPROTO)
else: 
  const 
    UV_EPROTO* = (- 4046)
when defined(EPROTONOSUPPORT) and not defined(windows):
  const 
    UV_EPROTONOSUPPORT* = (- EPROTONOSUPPORT)
else: 
  const 
    UV_EPROTONOSUPPORT* = (- 4045)
when defined(EPROTOTYPE) and not defined(windows):
  const 
    UV_EPROTOTYPE* = (- EPROTOTYPE)
else: 
  const 
    UV_EPROTOTYPE* = (- 4044)
when defined(EROFS) and not defined(windows):
  const 
    UV_EROFS* = (- EROFS)
else: 
  const 
    UV_EROFS* = (- 4043)
when defined(ESHUTDOWN) and not defined(windows):
  const 
    UV_ESHUTDOWN* = (- ESHUTDOWN)
else: 
  const 
    UV_ESHUTDOWN* = (- 4042)
when defined(ESPIPE) and not defined(windows):
  const 
    UV_ESPIPE* = (- ESPIPE)
else: 
  const 
    UV_ESPIPE* = (- 4041)
when defined(ESRCH) and not defined(windows):
  const 
    UV_ESRCH* = (- ESRCH)
else: 
  const 
    UV_ESRCH* = (- 4040)
when defined(ETIMEDOUT) and not defined(windows):
  const 
    UV_ETIMEDOUT* = (- ETIMEDOUT)
else: 
  const 
    UV_ETIMEDOUT* = (- 4039)
when defined(ETXTBSY) and not defined(windows):
  const 
    UV_ETXTBSY* = (- ETXTBSY)
else: 
  const 
    UV_ETXTBSY* = (- 4038)
when defined(EXDEV) and not defined(windows):
  const 
    UV_EXDEV* = (- EXDEV)
else: 
  const 
    UV_EXDEV* = (- 4037)
when defined(EFBIG) and not defined(windows):
  const 
    UV_EFBIG* = (- EFBIG)
else: 
  const 
    UV_EFBIG* = (- 4036)
when defined(ENOPROTOOPT) and not defined(windows):
  const 
    UV_ENOPROTOOPT* = (- ENOPROTOOPT)
else: 
  const 
    UV_ENOPROTOOPT* = (- 4035)
when defined(ERANGE) and not defined(windows):
  const 
    UV_ERANGE* = (- ERANGE)
else: 
  const 
    UV_ERANGE* = (- 4034)
when defined(ENXIO) and not defined(windows):
  const 
    UV_ENXIO* = (- ENXIO)
else: 
  const 
    UV_ENXIO* = (- 4033)
when defined(EMLINK) and not defined(windows):
  const 
    UV_EMLINK* = (- EMLINK)
else: 
  const 
    UV_EMLINK* = (- 4032)
# EHOSTDOWN is not visible on BSD-like systems when _POSIX_C_SOURCE is
#  defined. Fortunately, its value is always 64 so it's possible albeit
#  icky to hard-code it.
# 

when defined(EHOSTDOWN) and not defined(windows):
  const 
    UV_EHOSTDOWN* = (- EHOSTDOWN)
elif not defined(windows):
  const 
    UV_EHOSTDOWN* = (- 64)
else: 
  const 
    UV_EHOSTDOWN* = (- 4031)
