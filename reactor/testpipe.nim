## This module implements a loopback pipe suitable for testing packet based protocols.
import reactor/async, reactor/time, collections, random

type
  TestPipe* = ref object of Pipe[Buffer]
    myInput: Output[Buffer]
    myOutput: Input[Buffer]
    logPackets*: bool
    delay*: int
    delayJitter*: int
    packetLoss*: float
    mtu*: int
    bandwidth*: int # kBps
    name*: string

proc log(self: TestPipe, msg: string) =
  var msg = msg
  if self.name.len > 0:
    msg = self.name & ": " & msg
  stderr.writeLine msg

proc invokeSend(self: TestPipe, p: Buffer) =
  if not self.myInput.maybeSend(p):
    self.log "packed dropped"

proc loop(self: TestPipe) {.async.} =
  var bandwidthAccum = 0

  asyncFor p in self.myOutput:
    if self.logPackets:
      self.log $p

    if rand(1.0) < self.packetLoss:
      continue

    if self.bandwidth != 0:
      bandwidthAccum += p.len
      if self.bandwidth * 10 < bandwidthAccum:
        let ms = int(bandwidthAccum / self.bandwidth)
        await asyncSleep(ms)
        bandwidthAccum -= ms * self.bandwidth

    if self.mtu != 0 and p.len > self.mtu:
      self.log "dropping packet exceeding mtu"
      continue

    let realDelay = int(self.delay.float + (rand(2.0) - 1) * self.delayJitter.float)
    if realDelay > 0:
      asyncSleep(realDelay).then(proc() = self.invokeSend(p)).ignore
    else:
      self.invokeSend(p)

proc newTestPipe*(): TestPipe =
  let self = TestPipe()
  (self.input, self.myInput) = newInputOutputPair[Buffer]()
  (self.myOutput, self.output) = newInputOutputPair[Buffer]()

  self.loop().onErrorClose(self.myOutput)

  return self

proc newTwoWayTestPipe*(name: string="", mtu: int=0, bandwidth=0, logPackets=false): tuple[pipe1: TestPipe, pipe2: TestPipe, l: Pipe[Buffer], r: Pipe[Buffer]] =
  result.pipe1 = newTestPipe()
  result.pipe1.mtu = mtu
  result.pipe1.logPackets = logPackets
  result.pipe1.bandwidth = bandwidth
  result.pipe1.name = name & "[l->r]"
  result.pipe2 = newTestPipe()
  result.pipe2.mtu = mtu
  result.pipe2.logPackets = logPackets
  result.pipe2.bandwidth = bandwidth
  result.pipe2.name = name & "[r->l]"
  result.l = newPipe(result.pipe1.input, result.pipe2.output)
  result.r = newPipe(result.pipe2.input, result.pipe1.output)
