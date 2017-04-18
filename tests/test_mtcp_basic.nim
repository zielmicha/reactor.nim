import reactor/mtcp, reactor

initMtcp("tests/mtcp.config")

echo "init mtcp done"
initThreadLoopMtcp(core=0)

# mtcp_core_affinitize(core);
#sockid = mtcp_socket(mctx, AF_INET, SOCK_STREAM, 0);
#ret = mtcp_setsock_nonblock(mctx, sockid);
# mtcp_init_rss(mctx, saddr, 1, daddr, dport); saddr=INADDR_ANY

proc main() {.async.} =
  let conn = await connectTcp("10.0.0.1:80")
  echo "connected"

when isMainModule:
  main().runMain
