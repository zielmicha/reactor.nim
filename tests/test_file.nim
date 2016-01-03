import reactor/loop, reactor/async, reactor/file

open("/etc/passwd", ReadOnly).then(proc(x: FileFd) = echo x.int).ignore()

runLoop()
