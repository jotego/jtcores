# Cache Wide Stress Test

This simunit test drives `jtframe_cache` directly in two configurations:

- `DW=64`, `ENDIAN=0`
- `DW=128`, `ENDIAN=0`

Both runs use `BLOCKS=32`, `BLKSIZE=1kB`, a deterministic `512 KiB`
`payload.bin`, and `85.909 MHz` SDRAM timing with refresh requests every `64 us`.
By default, the stress scope is reduced to `STRESS_FILE_BYTES=131072`
(override with a `simunit.sh --macros` value).

## What It Verifies

- SDRAM starts blank and is populated only through `jtframe_cache` writes
- a scoped subset of the payload is written and read back through the cache for
  both widths (`STRESS_FILE_BYTES`, default `128 KiB`)
- returned `64-bit` and `128-bit` words match the original byte stream in
  little-endian lane order
- the underlying SDRAM half-word contents match the payload byte stream exactly
- line-start burst counts stay in the legal `0/1/2` classification used by the
  existing direct-cache stress bench
- refresh accounting is based on the real SDRAM refresh command footprint

The bench writes `test.lxt`. `simunit.sh` removes it after a passing run unless
called with `--keep`.
