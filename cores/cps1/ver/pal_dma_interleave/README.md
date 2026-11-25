# CPS1 palette DMA with competing video clients

This test extends `pal_dma_fixed` with periodic HB lines, enabled OBJ DMA,
and active scroll-1 DMA. The palette transfer must retain its fixed six-page
read count and write exactly 512 words to each enabled palette page while
other clients use the shared DMA scheduler. It checks masks
`00/01/02/03/0A/3F`, a control-mask change during transfer, two transfers
without resetting DMA state, and all 512 visible words of every palette page
against distinct source data.

Two runs deliberately raise HB when the palette reader is at word 511, the
delayed write pointer is at word 510, and the scheduler is at step 1. OBJ and
SCR1 reads then interrupt the page-boundary prefetch. The original candidate
let non-palette consumes overwrite `pal_wr_cnt` and `pal_din`; the boundary
reproducer observed 3,585 palette reads and 3,584 writes, rather than 3,073
reads and 3,072 writes for a full six-page copy. The corrected pipeline
updates those registers only on accepted palette reads. The test asserts
exact count and visible data after the interruption, including sparse mask
`0A`. It also asserts that OBJ and SCR1 consumed words during the transfer.

The synthetic immediate-acknowledgement schedule is deterministic but does
not model the full SDRAM controller. It locks the task-state and palette-RAM
contract, not absolute PCB clock timing. Physical provenance and the
same-image mask-cost comparison are documented in `../pal_dma_fixed/README.md`.

Run from the repository root after sourcing `setprj.sh`:

```sh
simunit-all.sh --only pal_dma_interleave
```
