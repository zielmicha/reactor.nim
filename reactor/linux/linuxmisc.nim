# these have potential of being unportable

when hostCPU == "mips" or hostCPU == "mipsel":
  const
    IOC_NONE = 1
    IOC_READ = 2
    IOC_WRITE = 4

  const
    IOC_SIZEBITS = 13
    IOC_DIRBITS = 3
else:
  const
    IOC_NONE = 0
    IOC_READ = 1
    IOC_WRITE = 2

  const
    IOC_SIZEBITS = 13
    IOC_DIRBITS = 2

const
  IOC_TYPEBITS = 8
  IOC_NRBITS = 8

const
  IOC_NRSHIFT = 0
  IOC_TYPESHIFT = IOC_NRSHIFT + IOC_NRBITS
  IOC_SIZESHIFT = IOC_TYPESHIFT + IOC_TYPEBITS
  IOC_DIRSHIFT = IOC_SIZESHIFT + IOC_SIZEBITS

proc IOC*(dir: int, `type`: int, nr: int, size: int): cint =
  return ((dir shl IOC_DIRSHIFT) or (`type` shl IOC_TYPESHIFT) or (nr shl IOC_NRSHIFT) or (size shl IOC_SIZESHIFT)).cint

template IOR*(`type`, nr, size): cint =
  IOC(IOC_READ, `type`.int, nr, sizeof(size))

template IOW*(`type`, nr, size): cint =
  IOC(IOC_WRITE, `type`.int, nr, sizeof(size))
