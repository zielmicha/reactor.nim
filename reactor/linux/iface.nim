#
#  INET		An implementation of the TCP/IP protocol suite for the LINUX
# 		operating system.  INET is implemented using the  BSD Socket
# 		interface as the means of communication with the user level.
# 
# 		Global definitions for the INET interface module.
# 
#  Version:	@(#)if.h	1.0.2	04/18/93
# 
#  Authors:	Original taken from Berkeley UNIX 4.3, (c) UCB 1982-1988
# 		Ross Biro
# 		Fred N. van Kempen, <waltje@uWalt.NL.Mugnet.ORG>
# 
# 		This program is free software; you can redistribute it and/or
# 		modify it under the terms of the GNU General Public License
# 		as published by the Free Software Foundation; either version
# 		2 of the License, or (at your option) any later version.
# 
import posix

const
  IFNAMSIZ* = 16
  IFALIASZ* = 256

#*
#  enum net_device_flags - &struct net_device flags
# 
#  These are the &struct net_device flags, they can be set by drivers, the
#  kernel and some can be triggered by userspace. Userspace can query and
#  set these flags using userspace utilities but there is also a sysfs
#  entry available for all dev flags which can be queried and set. These flags
#  are shared for all types of net_devices. The sysfs entries are available
#  via /sys/class/net/<dev>/flags. Flags which can be toggled through sysfs
#  are annotated below, note that only a few flags can be toggled and some
#  other flags are always always preserved from the original net_device flags
#  even if you try to set them via sysfs. Flags which are always preserved
#  are kept under the flag grouping @IFF_VOLATILE. Flags which are __volatile__
#  are annotated below as such.
# 
#  You should have a pretty good reason to be extending these flags.
# 
#  @IFF_UP: interface is up. Can be toggled through sysfs.
#  @IFF_BROADCAST: broadcast address valid. Volatile.
#  @IFF_DEBUG: turn on debugging. Can be toggled through sysfs.
#  @IFF_LOOPBACK: is a loopback net. Volatile.
#  @IFF_POINTOPOINT: interface is has p-p link. Volatile.
#  @IFF_NOTRAILERS: avoid use of trailers. Can be toggled through sysfs.
# 	Volatile.
#  @IFF_RUNNING: interface RFC2863 OPER_UP. Volatile.
#  @IFF_NOARP: no ARP protocol. Can be toggled through sysfs. Volatile.
#  @IFF_PROMISC: receive all packets. Can be toggled through sysfs.
#  @IFF_ALLMULTI: receive all multicast packets. Can be toggled through
# 	sysfs.
#  @IFF_MASTER: master of a load balancer. Volatile.
#  @IFF_SLAVE: slave of a load balancer. Volatile.
#  @IFF_MULTICAST: Supports multicast. Can be toggled through sysfs.
#  @IFF_PORTSEL: can set media type. Can be toggled through sysfs.
#  @IFF_AUTOMEDIA: auto media select active. Can be toggled through sysfs.
#  @IFF_DYNAMIC: dialup device with changing addresses. Can be toggled
# 	through sysfs.
#  @IFF_LOWER_UP: driver signals L1 up. Volatile.
#  @IFF_DORMANT: driver signals dormant. Volatile.
#  @IFF_ECHO: echo sent packets. Volatile.
# 

type
  net_device_flags* = enum
    IFF_UP = 1 shl 0,             # sysfs 
    IFF_BROADCAST = 1 shl 1,      # __volatile__ 
    IFF_DEBUG = 1 shl 2,          # sysfs 
    IFF_LOOPBACK = 1 shl 3,       # __volatile__ 
    IFF_POINTOPOINT = 1 shl 4,    # __volatile__ 
    IFF_NOTRAILERS = 1 shl 5,     # sysfs 
    IFF_RUNNING = 1 shl 6,        # __volatile__ 
    IFF_NOARP = 1 shl 7,          # sysfs 
    IFF_PROMISC = 1 shl 8,        # sysfs 
    IFF_ALLMULTI = 1 shl 9,       # sysfs 
    IFF_MASTER = 1 shl 10,        # __volatile__ 
    IFF_SLAVE = 1 shl 11,         # __volatile__ 
    IFF_MULTICAST = 1 shl 12,     # sysfs 
    IFF_PORTSEL = 1 shl 13,       # sysfs 
    IFF_AUTOMEDIA = 1 shl 14,     # sysfs 
    IFF_DYNAMIC = 1 shl 15,       # sysfs 
    IFF_LOWER_UP = 1 shl 16,      # __volatile__ 
    IFF_DORMANT = 1 shl 17,       # __volatile__ 
    IFF_ECHO = 1 shl 18           # __volatile__

const
  IF_GET_IFACE* = 0x00000001
  IF_GET_PROTO* = 0x00000002

# For definitions see hdlc.h 

const
  IF_IFACE_V35* = 0x00001000
  IF_IFACE_V24* = 0x00001001
  IF_IFACE_X21* = 0x00001002
  IF_IFACE_T1* = 0x00001003
  IF_IFACE_E1* = 0x00001004
  IF_IFACE_SYNC_SERIAL* = 0x00001005
  IF_IFACE_X21D* = 0x00001006

# For definitions see hdlc.h 

const
  IF_PROTO_HDLC* = 0x00002000
  IF_PROTO_PPP* = 0x00002001
  IF_PROTO_CISCO* = 0x00002002
  IF_PROTO_FR* = 0x00002003
  IF_PROTO_FR_ADD_PVC* = 0x00002004
  IF_PROTO_FR_DEL_PVC* = 0x00002005
  IF_PROTO_X25* = 0x00002006
  IF_PROTO_HDLC_ETH* = 0x00002007
  IF_PROTO_FR_ADD_ETH_PVC* = 0x00002008
  IF_PROTO_FR_DEL_ETH_PVC* = 0x00002009
  IF_PROTO_FR_PVC* = 0x0000200A
  IF_PROTO_FR_ETH_PVC* = 0x0000200B
  IF_PROTO_RAW* = 0x0000200C

# RFC 2863 operational status 

const
  IF_OPER_UNKNOWN* = 0
  IF_OPER_NOTPRESENT* = 1
  IF_OPER_DOWN* = 2
  IF_OPER_LOWERLAYERDOWN* = 3
  IF_OPER_TESTING* = 4
  IF_OPER_DORMANT* = 5
  IF_OPER_UP* = 6

# link modes 

const
  IF_LINK_MODE_DEFAULT* = 0
  IF_LINK_MODE_DORMANT* = 1     # limit upward transition to dormant 

#
# 	Device mapping structure. I'd just gone off and designed a 
# 	beautiful scheme using only loadable modules with arguments
# 	for driver options and along come the PCMCIA people 8)
# 
# 	Ah well. The get() side of this is good for WDSETUP, and it'll
# 	be handy for debugging things. The set side is fine for now and
# 	being very small might be worth keeping for clean configuration.
# 

type
  ifmap* = object
    mem_start*: culong
    mem_end*: culong
    base_addr*: cushort
    irq*: cuchar
    dma*: cuchar
    port*: cuchar              # 3 bytes spare 
  
  INNER_C_UNION_7690817765878444061* = object {.union.}
    raw_hdlc*: pointer # {atm/eth/dsl}_settings anyone ?
    cisco*: pointer
    fr*: pointer
    fr_pvc*: pointer
    fr_pvc_info*: pointer # interface settings
    sync*: pointer
    te1*: pointer

  if_settings* = object
    `type`*: cuint             # Type of physical device or protocol 
    size*: cuint               # Size of the data allocated by the caller 
    ifs_ifsu*: INNER_C_UNION_7690817765878444061


#
#  Interface request structure used for socket
#  ioctl's.  All interface ioctl's must have parameter
#  definitions which begin with ifr_name.  The
#  remainder may be interface specific.
# 

const
  IFHWADDRLEN* = 6

type
  INNER_C_UNION_9577892707352925678* = object {.union.}
    ifru_addr*: SockAddr
    ifru_dstaddr*: SockAddr
    ifru_broadaddr*: SockAddr
    ifru_netmask*: SockAddr
    ifru_hwaddr*: SockAddr
    ifru_flags*: cshort
    ifru_ivalue*: cint
    ifru_mtu*: cint
    ifru_map*: ifmap
    ifru_slave*: array[IFNAMSIZ, char] # Just fits the size 
    ifru_newname*: array[IFNAMSIZ, char]
    ifru_data*: pointer
    ifru_settings*: if_settings

  ifreq* = object
    ifrn_name*: array[IFNAMSIZ, char] # if name, e.g. "en0" 
    ifr_ifru*: INNER_C_UNION_9577892707352925678


#
#  Structure used in SIOCGIFCONF request.
#  Used to retrieve interface configuration
#  for machine (useful for programs which
#  must know all networks accessible).
# 

type
  INNER_C_UNION_7849047566647962952* = object {.union.}
    ifcu_buf*: cstring
    ifcu_req*: ptr ifreq

  ifconf* = object
    ifc_len*: cint             # size of buffer	
    ifc_ifcu*: INNER_C_UNION_7849047566647962952
