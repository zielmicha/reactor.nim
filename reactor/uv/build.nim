import os, osproc

const uvPath = splitPath(currentSourcePath()).head & "/../../deps/libuv/"

{.passc: "-I" & uvPath & "include".}
{.passc: "-I" & uvPath & "src".}

when defined(enableMtcp):
  const mtcpPath = splitPath(currentSourcePath()).head & "/../../deps/mtcp/"
  static:
    echo staticExec("make -C " & quoteShell(mtcpPath) & " -f simple.mk")
  const dpdkLibs = "-lnuma -lpthread -lrt -ldl -L/usr/local/lib -Wl,-lrte_kni -Wl,-lrte_pipeline -Wl,-lrte_table -Wl,-lrte_port -Wl,-lrte_pdump -Wl,-lrte_distributor -Wl,-lrte_reorder -Wl,-lrte_ip_frag -Wl,-lrte_meter -Wl,-lrte_sched -Wl,-lrte_lpm -Wl,--whole-archive -Wl,-lrte_acl -Wl,--no-whole-archive -Wl,-lrte_jobstats -Wl,-lrte_power -Wl,--whole-archive -Wl,-lrte_timer -Wl,-lrte_hash -Wl,-lrte_vhost -Wl,-lrte_kvargs -Wl,-lrte_mbuf -Wl,-lrte_net -Wl,-lrte_ethdev -Wl,-lrte_cryptodev -Wl,-lrte_mempool -Wl,-lrte_ring -Wl,-lrte_eal -Wl,-lrte_cmdline -Wl,-lrte_cfgfile -Wl,-lrte_pmd_bond -Wl,-lrte_pmd_af_packet -Wl,-lrte_pmd_bnxt -Wl,-lrte_pmd_cxgbe -Wl,-lrte_pmd_e1000 -Wl,-lrte_pmd_ena -Wl,-lrte_pmd_enic -Wl,-lrte_pmd_fm10k -Wl,-lrte_pmd_i40e -Wl,-lrte_pmd_ixgbe -Wl,-lrte_pmd_null -Wl,-lrte_pmd_pcap -Wl,-lpcap -Wl,-lrte_pmd_qede -Wl,-lrte_pmd_ring -Wl,-lrte_pmd_virtio -Wl,-lrte_pmd_vhost -Wl,-lrte_pmd_vmxnet3_uio -Wl,-lrte_pmd_null_crypto -Wl,--no-whole-archive -Wl,-lrt -Wl,-lm -Wl,-ldl"
  {.passl: mtcpPath & "/mtcp/lib/libmtcp.a " & dpdkLibs}
  {.passc: "-I" & mtcpPath & "/mtcp/include".}
  {.passc: "-DENABLE_MTCP".} # for libuv

{.compile: uvPath & "src/fs-poll.c"}
{.compile: uvPath & "src/inet.c"}
{.compile: uvPath & "src/threadpool.c"}
{.compile: uvPath & "src/uv-common.c"}
{.compile: uvPath & "src/version.c"}

when defined(macosx) or defined(linux):
  {.passc: "-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64".}
  {.compile: uvPath & "src/unix/async.c".}
  {.compile: uvPath & "src/unix/core.c".}
  {.compile: uvPath & "src/unix/dl.c".}
  {.compile: uvPath & "src/unix/fs.c".}
  {.compile: uvPath & "src/unix/getaddrinfo.c".}
  {.compile: uvPath & "src/unix/getnameinfo.c".}
  {.compile: uvPath & "src/unix/loop.c".}
  {.compile: uvPath & "src/unix/loop-watcher.c".}
  {.compile: uvPath & "src/unix/pipe.c".}
  {.compile: uvPath & "src/unix/poll.c".}
  {.compile: uvPath & "src/unix/process.c".}
  {.compile: uvPath & "src/unix/signal.c".}
  {.compile: uvPath & "src/unix/stream.c".}
  {.compile: uvPath & "src/unix/tcp.c".}
  {.compile: uvPath & "src/unix/thread.c".}
  {.compile: uvPath & "src/unix/timer.c".}
  {.compile: uvPath & "src/unix/tty.c".}
  {.compile: uvPath & "src/unix/udp.c".}

when defined(linux):
  {.compile: uvPath & "src/unix/linux-core.c"}
  {.compile: uvPath & "src/unix/linux-inotify.c"}
  {.compile: uvPath & "src/unix/linux-syscalls.c"}

when defined(macosx):
  {.passc: "-D_DARWIN_USE_64_BIT_INODE=1".}
  {.compile: uvPath & "src/unix/kqueue.c"}
  {.compile: uvPath & "src/unix/darwin.c".}
  {.compile: uvPath & "src/unix/fsevents.c".}
  {.compile: uvPath & "src/unix/darwin-proctitle.c".}

when defined(windows):
  {.compile: uvPath & "src/win/async.c".}
  {.compile: uvPath & "src/win/core.c".}
  {.compile: uvPath & "src/win/dl.c".}
  {.compile: uvPath & "src/win/error.c".}
  {.compile: uvPath & "src/win/fs.c".}
  {.compile: uvPath & "src/win/fs-event.c".}
  {.compile: uvPath & "src/win/getaddrinfo.c".}
  {.compile: uvPath & "src/win/getnameinfo.c".}
  {.compile: uvPath & "src/win/handle.c".}
  {.compile: uvPath & "src/win/loop-watcher.c".}
  {.compile: uvPath & "src/win/pipe.c".}
  {.compile: uvPath & "src/win/thread.c".}
  {.compile: uvPath & "src/win/poll.c".}
  {.compile: uvPath & "src/win/process.c".}
  {.compile: uvPath & "src/win/process-stdio.c".}
  {.compile: uvPath & "src/win/req.c".}
  {.compile: uvPath & "src/win/signal.c".}
  {.compile: uvPath & "src/win/stream.c".}
  {.compile: uvPath & "src/win/tcp.c".}
  {.compile: uvPath & "src/win/tty.c".}
  {.compile: uvPath & "src/win/timer.c".}
  {.compile: uvPath & "src/win/udp.c".}
  {.compile: uvPath & "src/win/util.c".}
  {.compile: uvPath & "src/win/winapi.c".}
  {.compile: uvPath & "src/win/winsock.c".}
