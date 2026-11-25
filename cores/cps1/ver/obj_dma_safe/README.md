# CPS1 frame-boundary object copy candidate

Production MMR, DMA, and CPS_VRAM with a registered synthetic grant and shortened
384-master-clock horizontal lines (262 lines/frame). This is a bounded structural
test, not a physical CPU-timing calibration. It checks full1024-word source/data
sequences, cache prefix/end-marker/zero tail, equal HOLD/TRIG cadence and request
budgets, a mid-copy base rewrite, and ACK withholding from line250 through the
next boundary until line10. The checker uses accepted-word counts, copy position,
bank transitions, source addresses/data, and cache readback; it does not depend
on diagnostic pending/overrun flags. Display-bank changes require line0 and a
previously completed copy. Completion mid-visible must keep the old read bank
until the next boundary, which samples the fresh current base rather than a
missed snapshot.

Run from repository root after `source setprj.sh` using
`simunit-all.sh --jobs 1 --only obj_dma_safe --keep`. The test covers the
frame-boundary object DMA behavior implemented in `jtcps1_dma.v`. The prior
pending-consumption implementation fails the bank-boundary assertion.
