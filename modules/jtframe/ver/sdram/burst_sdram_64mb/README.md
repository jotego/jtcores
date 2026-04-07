# 64MB Burst SDRAM Unit Test

This simunit test checks `jtframe_burst_sdram` with `AW=23` against the
`mt48lc16m16a2` SDRAM model configured as a 64MB device (`col_bits=10`).

## What It Verifies

- SDRAM initialization completes with the 64MB geometry
- the SDRAM model can preload bank 3 from a generated `sdram_bank3.bin`
- runtime burst reads from bank 3 return the same words stored in that file
- `ack` strobes when a burst request is accepted
- `dst` only marks the first returned word in a burst
- `rdy` is asserted when the requested burst completes

## Test Flow

1. `init.go` generates a deterministic 16 MiB `sdram_bank3.bin`.
2. The testbench loads the same file into a local expected-memory array.
3. The bench waits for SDRAM initialization to complete.
4. It issues a few boundary-focused bursts, then deterministic pseudo-random
   bursts across the full 16 MiB bank-3 address space.
5. `clean_up.sh` removes the generated `sdram_bank3.bin` after the run.
