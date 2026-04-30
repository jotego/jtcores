# SH7604 Async Memory Verilator Test

This test instantiates the `jtsh7604` wrapper and connects its external bus to:

- a 16 MB asynchronous SRAM model used for boot code, test data, and RAM
- a status write register at `0x06000000` watched by the C++ runner

The top-level simulation clock is 80 MHz. The CPU receives `CE_R` every fourth
clock and `CE_F` two clocks later, so the SH7604 runs at 20 MHz bus phasing.

Run it from this directory after sourcing `setprj.sh`:

```bash
bash ./sim.sh
```

Use `--keep` to build with FST tracing and keep `test.fst`.
