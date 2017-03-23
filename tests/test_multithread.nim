import reactor, reactor/threading, os

let mloop = newMultiLoop(threadCount=16, pin=false)
echo "count:", mloop.threadCount

mloop.execOnThread(0, proc() = echo threadLoopId(), ": hello from zero")
mloop.execOnAllThreads(proc() = echo threadLoopId(), ": hello")
mloop.execOnAllThreads(proc() = echo threadLoopId(), ": world")
os.sleep(1000)
mloop.execOnAllThreads(proc() = echo threadLoopId(), ": bum")
os.sleep(1000)
