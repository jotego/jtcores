# SDRAM slot latency

Exercises the shared logic used by the generated `jtframe_ramN_Mslots` and
`jtframe_rom_Nslots` wrappers. The test measures:

- one-clock request-to-SDRAM-command latency for a writable RAM slot;
- writable-slot read data and write address/data/mask routing;
- cache-hit latency for a read-only ROM slot;
- cache-hit latency for both block-cache and configurable-cache ROM paths;
- returned data and request deassertion.

`jtframe_ram1_2slots` is representative because it combines both slot types
with the common `jtframe_ramslot_ctrl` arbiter. A `jtframe_rom_1slot` instance
selects the alternate configurable-cache path.
