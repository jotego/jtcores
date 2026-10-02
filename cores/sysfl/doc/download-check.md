# Verifying the download-built opq tables

The opq tables are built from the download stream by logic that regular
sims never exercise: jtsim shortens the ROM download to 32 bytes and
preloads the SDRAM banks directly. The tables therefore need an explicit
check after any change to the builders, the download path or the bank
layout:

1. Build a full-length rom.bin (header + unswabbed sdram bank images in
   address order, truncated after the last mask region).
2. Swap it in and run `jtsim -load -video 20 speed1_fast.cab`.
3. Expect `SOPQ built pop=47316` and `ROPQ built pop=7572` (speedrcr).
4. Restore the stub rom.bin and rerun `make_sdram.py --fastboot` plus
   `touch rom.bin sdram_bank*.bin`: jtsim rewrites the bank files on
   exit, and stale banks corrupt every later scene sim.

On hardware the populations are on the debug OSD: 30h reads B8 for
Speed Racer and 72 for Final Lap R, B0h reads 76 for both. A zero means
the builder never saw the stream: the classic cause is reset gating,
since the whole download happens while the game is held in reset.
