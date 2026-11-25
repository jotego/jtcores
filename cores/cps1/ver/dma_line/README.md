# CPS1 line DMA header and SCR3 cadence

Drives `jtcps1_dma` with the production `jtcps1_timing` and an immediate bus
grant. It checks the CPS1 line DMA timing measured on the SF2 90629B-3 PCB
(issues #226 and #229):

- With no DMA task, the bus is still requested on every line and held for the
  ~0.6 us header. With the CPU grant handshake, a full-core simulation gives
  0.58-0.63 us of BGACK per idle line (PCB 604 ns), 1.74 us with object DMA
  (PCB 1.64 us) and 2.00 us with object DMA and row scroll (PCB 2.06 us).
- SCR3 tiles are 32 lines tall and its tile row is fetched every 32 lines.

Run with `simunit-all.sh --only dma_line`.
