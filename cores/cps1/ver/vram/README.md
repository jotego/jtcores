# Shared CPS VRAM

Tests the CPS_VRAM path in jtcps1_sdram: reset clearing, all three 64 KiB
banks and their boundaries, CPU word/byte writes, masked writes, CPU and
DMA readback, and DMA address changes with CS held high. It also checks
that VRAM bypasses SDRAM while work/object RAM still select it.

Run from the project root with `simunit-all.sh --only jtcps1_sdram`.
The SDRAM response inputs are idle; this test isolates the BRAM interface.
Whole-core boot simulations and synthesis cover the combined memory system.
