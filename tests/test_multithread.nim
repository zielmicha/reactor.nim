import reactor, reactor/threading, os

startMultiloop(threadCount=16, pin=false)
echo "count:", threadLoopCount()

runOnThread(0, proc() = echo threadLoopId(), ": hello from zero")
runOnAllThreads(proc() = echo threadLoopId(), ": hello")
runOnAllThreads(proc() = echo threadLoopId(), ": world")
os.sleep(1000)
runOnAllThreads(proc() = echo threadLoopId(), ": bum")
os.sleep(1000)
