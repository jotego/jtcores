# Cache Stress Test

This simunit test drives `jtframe_cache` directly as a `DW=32`, `ENDIAN=1`
cache against `jtframe_burst_sdram` and the `mt48lc16m16a2` SDRAM model with
`BLOCKS=32`.

## What It Verifies

- `init.go` generates a deterministic 512 KiB `payload.bin`
- SDRAM starts blank and is populated only through `jtframe_cache` writes
- the file is written as 32-bit big-endian words through the cache interface
- the whole file is then read back through the cache interface
- readback matches the original file contents for all 131,072 words
- the written SDRAM half-word layout matches the expected big-endian byte order
- refresh requests are issued every 64 us while the cache traffic is running
- refresh accounting is based on the actual SDRAM refresh command (`0001` on
  `/CS /RAS /CAS /WE`), not just on the request pulse
- the test runs the SDRAM path at 85.909 MHz

## Test Flow

1. `init.go` generates a deterministic 512 KiB binary payload.
2. The testbench loads the file into a byte array and zeros the used SDRAM area.
3. It waits for SDRAM initialization to complete.
4. It writes every 32-bit word through `jtframe_cache`.
5. The sequential write phase fills the cache and then exercises dirty
   replacement traffic with a realistic line count.
6. It reads every 32-bit word back through `jtframe_cache`.
7. It directly checks the underlying SDRAM half-words to confirm big-endian
   storage order.

The bench writes `test.lxt` like the other simunit tests. `simunit.sh` removes
it after a passing run unless called with `--keep`.
