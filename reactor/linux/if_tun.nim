#
#   Universal TUN/TAP device driver.
#   Copyright (C) 1999-2000 Maxim Krasnyansky <max_mk@yahoo.com>
# 
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
# 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#   GNU General Public License for more details.
# 

# Read queue size 

const
  TUN_READQ_SIZE* = 500

# TUN device type flags: deprecated. Use IFF_TUN/IFF_TAP instead. 

# Ioctl defines 

import reactor/linux/linuxmisc

const
  TUNSETNOCSUM* = IOW('T', 200, cint)
  TUNSETDEBUG* = IOW('T', 201, cint)
  TUNSETIFF* = IOW('T', 202, cint)
  TUNSETPERSIST* = IOW('T', 203, cint)
  TUNSETOWNER* = IOW('T', 204, cint)
  TUNSETLINK* = IOW('T', 205, cint)
  TUNSETGROUP* = IOW('T', 206, cint)
  TUNGETFEATURES* = IOR('T', 207, cuint)
  TUNSETOFFLOAD* = IOW('T', 208, cuint)
  TUNSETTXFILTER* = IOW('T', 209, cuint)
  TUNGETIFF* = IOR('T', 210, cuint)
  TUNGETSNDBUF* = IOR('T', 211, cint)
  TUNSETSNDBUF* = IOW('T', 212, cint)
  #TUNATTACHFILTER* = IOW('T', 213, struct sock_fprog)
  #TUNDETACHFILTER* = IOW('T', 214, struct sock_fprog)
  TUNGETVNETHDRSZ* = IOR('T', 215, cint)
  TUNSETVNETHDRSZ* = IOW('T', 216, cint)
  TUNSETQUEUE* = IOW('T', 217, cint)
  TUNSETIFINDEX* = IOW('T', 218, cuint)
  #TUNGETFILTER* = IOR('T', 219, struct sock_fprog)
  TUNSETVNETLE* = IOW('T', 220, cint)
  TUNGETVNETLE* = IOR('T', 221, cint)

# The TUNSETVNETBE and TUNGETVNETBE ioctls are for cross-endian support on
#  little-endian hosts. Not all kernel configurations support them, but all
#  configurations that support SET also support GET.
# 

const
  TUNSETVNETBE* = IOW('T', 222, int)
  TUNGETVNETBE* = IOR('T', 223, int)

# TUNSETIFF ifr flags 

const
  IFF_TUN* = 0x00000001
  IFF_TAP* = 0x00000002
  IFF_NO_PI* = 0x00001000

# This flag has no real effect 

const
  IFF_ONE_QUEUE* = 0x00002000
  IFF_VNET_HDR* = 0x00004000
  IFF_TUN_EXCL* = 0x00008000
  IFF_MULTI_QUEUE* = 0x00000100
  IFF_ATTACH_QUEUE* = 0x00000200
  IFF_DETACH_QUEUE* = 0x00000400

# read-only flag 

const
  IFF_PERSIST* = 0x00000800
  IFF_NOFILTER* = 0x00001000

# Socket options 

const
  TUN_TX_TIMESTAMP* = 1

# Features for GSO (TUNSETOFFLOAD). 

const
  TUN_F_CSUM* = 0x00000001
  TUN_F_TSO4* = 0x00000002
  TUN_F_TSO6* = 0x00000004
  TUN_F_TSO_ECN* = 0x00000008
  TUN_F_UFO* = 0x00000010

# Protocol info prepended to the packets (when IFF_NO_PI is not set) 

const
  TUN_PKT_STRIP* = 0x00000001

type
  tun_pi* = object
    flags*: uint16
    proto*: uint16


#
#  Filter spec (used for SETXXFILTER ioctls)
#  This stuff is applicable only to the TAP (Ethernet) devices.
#  If the count is zero the filter is disabled and the driver accepts
#  all packets (promisc mode).
#  If the filter is enabled in order to accept broadcast packets
#  broadcast addr must be explicitly included in the addr list.
# 

const
  TUN_FLT_ALLMULTI* = 0x00000001

# type
#   tun_filter* = object
#     flags*: uint16              # TUN_FLT_ flags see above
#     count*: uint16             # Number of addresses
#     #`addr`*: array[0, array[ETH_ALEN, __u8]]
