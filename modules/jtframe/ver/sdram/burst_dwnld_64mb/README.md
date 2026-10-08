# 64 MB Burst SDRAM Download Test

This Verilator test checks the 64 MB ROM-download path used when
`JTFRAME_SDRAM_LARGE` is enabled.

The test drives `jtframe_dwnld` into `jtframe_burst_sdram` with four 16 MB
download regions:

- bank 0 starts at byte `0x0000000`
- bank 1 starts at byte `0x1000000`
- bank 2 starts at byte `0x2000000`
- bank 3 starts at byte `0x3000000`

The C++ driver creates a deterministic random `download.bin`, computes the
CRC32 of each 16 MB chunk, transfers the file byte-by-byte through the ioctl
download interface, then reads the data back through the burst SDRAM runtime
port and compares the CRC32 values.

## Run

```bash
source setprj.sh >/dev/null
bash modules/jtframe/ver/sdram/burst_dwnld_64mb/sim.sh
```

The full 64 MB run is intentionally long. For a quick compile/smoke run:

```bash
bash modules/jtframe/ver/sdram/burst_dwnld_64mb/sim.sh --bytes 65536
```

Use `--keep` to build with FST tracing and keep `test.fst`. Use
`--keep-data` to keep the generated `download.bin`.

Use `--balut-forward` to prepend a high/low BALUT header and build
`jtframe_dwnld` with `BALUT_REVERSE=0`. Use `--balut-reverse` to prepend a
low/high BALUT header and build with `BALUT_REVERSE=1`.
