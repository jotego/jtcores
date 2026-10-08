# SH7604 DMAC Readback Unit Test

This test targets the SH7604 DMAC non-burst longword memory-to-memory path.

It starts a channel 0 auto-request DMA, presents an expected source read value
on `DBUS_DI`, lets the DMAC advance into the write phase, then changes
`DBUS_DI` before the write is accepted. The write data on `DBUS_DO` must remain
the source read value, not the live destination-side bus input.

Run it locally with:

```bash
source modules/jtframe/bin/setprj.sh >/dev/null
simunit.sh --run modules/jtframe/ver/cpu/sh7604_dmac_readback
```
