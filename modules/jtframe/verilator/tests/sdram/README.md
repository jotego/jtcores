# Verilator SDRAM Native Tests

This folder contains standalone C++ tests for the JTFRAME Verilator SDRAM
model in [`modules/jtframe/verilator/sdram.cpp`](../../sdram.cpp).

The tests cover:

- fixed-length and full-page read bursts
- sequential and interleaved burst addressing
- burst stop behavior
- multi-beat writes and write-single mode
- DQM masking on reads and writes
- read/write interruption
- bank precharge and auto-precharge behavior
- both JTFRAME SDRAM geometries used by the model: `COLW=9` and `COLW=10`

Run them with:

```bash
cd modules/jtframe/verilator/tests/sdram
make test
```
