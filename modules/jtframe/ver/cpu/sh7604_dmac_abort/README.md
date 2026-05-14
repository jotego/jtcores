# SH7604 DMAC Abort Unit Test

This test targets SH7604 DMAC channel 0 active-transfer abort behavior.

It starts an auto-request memory-to-memory DMA, stalls the external data bus
while the DMAC is in the write phase, clears `DMAOR.DME`, reprograms channel 0
with `TCR0=1`, and releases the stall. The expected hardware behavior is that
the disabled, in-flight phase cannot consume or mutate the newly programmed
transfer.

The `.simunit` file uses `--skip` so this known-bug reproducer does not run in
GitHub Actions until the RTL is fixed. It still runs locally with:

```bash
source modules/jtframe/bin/setprj.sh >/dev/null
simunit.sh --run modules/jtframe/ver/cpu/sh7604_dmac_abort
```
