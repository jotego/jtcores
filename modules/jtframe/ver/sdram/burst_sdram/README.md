# Burst SDRAM Unit Test

This simunit test checks the `jtframe_burst_sdram` controller against the
`mt48lc16m16a2` SDRAM model.

## What It Verifies

- SDRAM initialization completes and the controller leaves `init`
- the programming path accepts byte-wide ROM download traffic through
  `jtframe_dwnld`
- downloaded contents can be read back through the runtime burst interface
- `ack` strobes when a burst request is accepted
- `dst` only marks the first returned read word
- `dok` stays high while read data is being returned
- `rdy` is asserted when the shortened read or write burst completes
- a runtime write burst updates SDRAM contents and the new words can be read
  back correctly

## Test Flow

1. Reset the controller and wait for SDRAM initialization to finish.
2. Download a small byte pattern through the programmer interface.
3. Issue a short read burst and compare each returned word against the
   downloaded pattern.
4. Issue a short write burst with a new word pattern.
5. Read back the overwritten range and compare it against the write data.

The bench focuses on the single-consumer burst handshake exposed by
`jtframe_burst_sdram`, not on the multi-bank behavior of `jtframe_sdram64`.
