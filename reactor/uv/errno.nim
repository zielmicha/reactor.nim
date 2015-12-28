# Copyright Joyent, Inc. and other Node contributors. All rights reserved.
# 
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to
#  deal in the Software without restriction, including without limitation the
#  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
#  sell copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
# 
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
# 
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
#  IN THE SOFTWARE.
# 

const 
  UV_x_EOF* = (- 4095)
  UV_x_UNKNOWN* = (- 4094)
  UV_x_EAI_ADDRFAMILY* = (- 3000)
  UV_x_EAI_AGAIN* = (- 3001)
  UV_x_EAI_BADFLAGS* = (- 3002)
  UV_x_EAI_CANCELED* = (- 3003)
  UV_x_EAI_FAIL* = (- 3004)
  UV_x_EAI_FAMILY* = (- 3005)
  UV_x_EAI_MEMORY* = (- 3006)
  UV_x_EAI_NODATA* = (- 3007)
  UV_x_EAI_NONAME* = (- 3008)
  UV_x_EAI_OVERFLOW* = (- 3009)
  UV_x_EAI_SERVICE* = (- 3010)
  UV_x_EAI_SOCKTYPE* = (- 3011)
  UV_x_EAI_BADHINTS* = (- 3013)
  UV_x_EAI_PROTOCOL* = (- 3014)

# Only map to the system errno on non-Windows platforms. It's apparently
#  a fairly common practice for Windows programmers to redefine errno codes.
# 

when defined(E2BIG) and not defined(windows):
  const 
    UV_x_E2BIG* = (- E2BIG)
else: 
  const 
    UV_x_E2BIG* = (- 4093)
when defined(EACCES) and not defined(windows):
  const 
    UV_x_EACCES* = (- EACCES)
else: 
  const 
    UV_x_EACCES* = (- 4092)
when defined(EADDRINUSE) and not defined(windows):
  const 
    UV_x_EADDRINUSE* = (- EADDRINUSE)
else: 
  const 
    UV_x_EADDRINUSE* = (- 4091)
when defined(EADDRNOTAVAIL) and not defined(windows):
  const 
    UV_x_EADDRNOTAVAIL* = (- EADDRNOTAVAIL)
else: 
  const 
    UV_x_EADDRNOTAVAIL* = (- 4090)
when defined(EAFNOSUPPORT) and not defined(windows):
  const 
    UV_x_EAFNOSUPPORT* = (- EAFNOSUPPORT)
else: 
  const 
    UV_x_EAFNOSUPPORT* = (- 4089)
when defined(EAGAIN) and not defined(windows):
  const 
    UV_x_EAGAIN* = (- EAGAIN)
else: 
  const 
    UV_x_EAGAIN* = (- 4088)
when defined(EALREADY) and not defined(windows):
  const 
    UV_x_EALREADY* = (- EALREADY)
else: 
  const 
    UV_x_EALREADY* = (- 4084)
when defined(EBADF) and not defined(windows):
  const 
    UV_x_EBADF* = (- EBADF)
else: 
  const 
    UV_x_EBADF* = (- 4083)
when defined(EBUSY) and not defined(windows):
  const 
    UV_x_EBUSY* = (- EBUSY)
else: 
  const 
    UV_x_EBUSY* = (- 4082)
when defined(ECANCELED) and not defined(windows):
  const 
    UV_x_ECANCELED* = (- ECANCELED)
else: 
  const 
    UV_x_ECANCELED* = (- 4081)
when defined(ECHARSET) and not defined(windows):
  const 
    UV_x_ECHARSET* = (- ECHARSET)
else: 
  const 
    UV_x_ECHARSET* = (- 4080)
when defined(ECONNABORTED) and not defined(windows):
  const 
    UV_x_ECONNABORTED* = (- ECONNABORTED)
else: 
  const 
    UV_x_ECONNABORTED* = (- 4079)
when defined(ECONNREFUSED) and not defined(windows):
  const 
    UV_x_ECONNREFUSED* = (- ECONNREFUSED)
else: 
  const 
    UV_x_ECONNREFUSED* = (- 4078)
when defined(ECONNRESET) and not defined(windows):
  const 
    UV_x_ECONNRESET* = (- ECONNRESET)
else: 
  const 
    UV_x_ECONNRESET* = (- 4077)
when defined(EDESTADDRREQ) and not defined(windows):
  const 
    UV_x_EDESTADDRREQ* = (- EDESTADDRREQ)
else: 
  const 
    UV_x_EDESTADDRREQ* = (- 4076)
when defined(EEXIST) and not defined(windows):
  const 
    UV_x_EEXIST* = (- EEXIST)
else: 
  const 
    UV_x_EEXIST* = (- 4075)
when defined(EFAULT) and not defined(windows):
  const 
    UV_x_EFAULT* = (- EFAULT)
else: 
  const 
    UV_x_EFAULT* = (- 4074)
when defined(EHOSTUNREACH) and not defined(windows):
  const 
    UV_x_EHOSTUNREACH* = (- EHOSTUNREACH)
else: 
  const 
    UV_x_EHOSTUNREACH* = (- 4073)
when defined(EINTR) and not defined(windows):
  const 
    UV_x_EINTR* = (- EINTR)
else: 
  const 
    UV_x_EINTR* = (- 4072)
when defined(EINVAL) and not defined(windows):
  const 
    UV_x_EINVAL* = (- EINVAL)
else: 
  const 
    UV_x_EINVAL* = (- 4071)
when defined(EIO) and not defined(windows):
  const 
    UV_x_EIO* = (- EIO)
else: 
  const 
    UV_x_EIO* = (- 4070)
when defined(EISCONN) and not defined(windows):
  const 
    UV_x_EISCONN* = (- EISCONN)
else: 
  const 
    UV_x_EISCONN* = (- 4069)
when defined(EISDIR) and not defined(windows):
  const 
    UV_x_EISDIR* = (- EISDIR)
else: 
  const 
    UV_x_EISDIR* = (- 4068)
when defined(ELOOP) and not defined(windows):
  const 
    UV_x_ELOOP* = (- ELOOP)
else: 
  const 
    UV_x_ELOOP* = (- 4067)
when defined(EMFILE) and not defined(windows):
  const 
    UV_x_EMFILE* = (- EMFILE)
else: 
  const 
    UV_x_EMFILE* = (- 4066)
when defined(EMSGSIZE) and not defined(windows):
  const 
    UV_x_EMSGSIZE* = (- EMSGSIZE)
else: 
  const 
    UV_x_EMSGSIZE* = (- 4065)
when defined(ENAMETOOLONG) and not defined(windows):
  const 
    UV_x_ENAMETOOLONG* = (- ENAMETOOLONG)
else: 
  const 
    UV_x_ENAMETOOLONG* = (- 4064)
when defined(ENETDOWN) and not defined(windows):
  const 
    UV_x_ENETDOWN* = (- ENETDOWN)
else: 
  const 
    UV_x_ENETDOWN* = (- 4063)
when defined(ENETUNREACH) and not defined(windows):
  const 
    UV_x_ENETUNREACH* = (- ENETUNREACH)
else: 
  const 
    UV_x_ENETUNREACH* = (- 4062)
when defined(ENFILE) and not defined(windows):
  const 
    UV_x_ENFILE* = (- ENFILE)
else: 
  const 
    UV_x_ENFILE* = (- 4061)
when defined(ENOBUFS) and not defined(windows):
  const 
    UV_x_ENOBUFS* = (- ENOBUFS)
else: 
  const 
    UV_x_ENOBUFS* = (- 4060)
when defined(ENODEV) and not defined(windows):
  const 
    UV_x_ENODEV* = (- ENODEV)
else: 
  const 
    UV_x_ENODEV* = (- 4059)
when defined(ENOENT) and not defined(windows):
  const 
    UV_x_ENOENT* = (- ENOENT)
else: 
  const 
    UV_x_ENOENT* = (- 4058)
when defined(ENOMEM) and not defined(windows):
  const 
    UV_x_ENOMEM* = (- ENOMEM)
else: 
  const 
    UV_x_ENOMEM* = (- 4057)
when defined(ENONET) and not defined(windows):
  const 
    UV_x_ENONET* = (- ENONET)
else: 
  const 
    UV_x_ENONET* = (- 4056)
when defined(ENOSPC) and not defined(windows):
  const 
    UV_x_ENOSPC* = (- ENOSPC)
else: 
  const 
    UV_x_ENOSPC* = (- 4055)
when defined(ENOSYS) and not defined(windows):
  const 
    UV_x_ENOSYS* = (- ENOSYS)
else: 
  const 
    UV_x_ENOSYS* = (- 4054)
when defined(ENOTCONN) and not defined(windows):
  const 
    UV_x_ENOTCONN* = (- ENOTCONN)
else: 
  const 
    UV_x_ENOTCONN* = (- 4053)
when defined(ENOTDIR) and not defined(windows):
  const 
    UV_x_ENOTDIR* = (- ENOTDIR)
else: 
  const 
    UV_x_ENOTDIR* = (- 4052)
when defined(ENOTEMPTY) and not defined(windows):
  const 
    UV_x_ENOTEMPTY* = (- ENOTEMPTY)
else: 
  const 
    UV_x_ENOTEMPTY* = (- 4051)
when defined(ENOTSOCK) and not defined(windows):
  const 
    UV_x_ENOTSOCK* = (- ENOTSOCK)
else: 
  const 
    UV_x_ENOTSOCK* = (- 4050)
when defined(ENOTSUP) and not defined(windows):
  const 
    UV_x_ENOTSUP* = (- ENOTSUP)
else: 
  const 
    UV_x_ENOTSUP* = (- 4049)
when defined(EPERM) and not defined(windows):
  const 
    UV_x_EPERM* = (- EPERM)
else: 
  const 
    UV_x_EPERM* = (- 4048)
when defined(EPIPE) and not defined(windows):
  const 
    UV_x_EPIPE* = (- EPIPE)
else: 
  const 
    UV_x_EPIPE* = (- 4047)
when defined(EPROTO) and not defined(windows):
  const 
    UV_x_EPROTO* = (- EPROTO)
else: 
  const 
    UV_x_EPROTO* = (- 4046)
when defined(EPROTONOSUPPORT) and not defined(windows):
  const 
    UV_x_EPROTONOSUPPORT* = (- EPROTONOSUPPORT)
else: 
  const 
    UV_x_EPROTONOSUPPORT* = (- 4045)
when defined(EPROTOTYPE) and not defined(windows):
  const 
    UV_x_EPROTOTYPE* = (- EPROTOTYPE)
else: 
  const 
    UV_x_EPROTOTYPE* = (- 4044)
when defined(EROFS) and not defined(windows):
  const 
    UV_x_EROFS* = (- EROFS)
else: 
  const 
    UV_x_EROFS* = (- 4043)
when defined(ESHUTDOWN) and not defined(windows):
  const 
    UV_x_ESHUTDOWN* = (- ESHUTDOWN)
else: 
  const 
    UV_x_ESHUTDOWN* = (- 4042)
when defined(ESPIPE) and not defined(windows):
  const 
    UV_x_ESPIPE* = (- ESPIPE)
else: 
  const 
    UV_x_ESPIPE* = (- 4041)
when defined(ESRCH) and not defined(windows):
  const 
    UV_x_ESRCH* = (- ESRCH)
else: 
  const 
    UV_x_ESRCH* = (- 4040)
when defined(ETIMEDOUT) and not defined(windows):
  const 
    UV_x_ETIMEDOUT* = (- ETIMEDOUT)
else: 
  const 
    UV_x_ETIMEDOUT* = (- 4039)
when defined(ETXTBSY) and not defined(windows):
  const 
    UV_x_ETXTBSY* = (- ETXTBSY)
else: 
  const 
    UV_x_ETXTBSY* = (- 4038)
when defined(EXDEV) and not defined(windows):
  const 
    UV_x_EXDEV* = (- EXDEV)
else: 
  const 
    UV_x_EXDEV* = (- 4037)
when defined(EFBIG) and not defined(windows):
  const 
    UV_x_EFBIG* = (- EFBIG)
else: 
  const 
    UV_x_EFBIG* = (- 4036)
when defined(ENOPROTOOPT) and not defined(windows):
  const 
    UV_x_ENOPROTOOPT* = (- ENOPROTOOPT)
else: 
  const 
    UV_x_ENOPROTOOPT* = (- 4035)
when defined(ERANGE) and not defined(windows):
  const 
    UV_x_ERANGE* = (- ERANGE)
else: 
  const 
    UV_x_ERANGE* = (- 4034)
when defined(ENXIO) and not defined(windows):
  const 
    UV_x_ENXIO* = (- ENXIO)
else: 
  const 
    UV_x_ENXIO* = (- 4033)
when defined(EMLINK) and not defined(windows):
  const 
    UV_x_EMLINK* = (- EMLINK)
else: 
  const 
    UV_x_EMLINK* = (- 4032)
# EHOSTDOWN is not visible on BSD-like systems when _POSIX_C_SOURCE is
#  defined. Fortunately, its value is always 64 so it's possible albeit
#  icky to hard-code it.
# 

when defined(EHOSTDOWN) and not defined(windows):
  const 
    UV_x_EHOSTDOWN* = (- EHOSTDOWN)
elif not defined(windows):
  const 
    UV_x_EHOSTDOWN* = (- 64)
else: 
  const 
    UV_x_EHOSTDOWN* = (- 4031)
