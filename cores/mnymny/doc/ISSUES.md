# Open video issues (attract/demo, compared against original hardware video)

## 5. High scores not saved - ACTIVE

- Symptom: "Todays high scores" reset every power cycle; the Table Title
  DIP (Todays / All time, SW 3I) suggests the board kept an all-time
  table in battery-backed RAM.
- Hardware: 7000-77FF work RAM; the 2C/2D half (upper 1KB? confirm on
  sheet 1) is the battery-backed section on the real board. The game
  keeps the all-time table there.
- Current plumbing: mem.yaml wram has ioctl save+restore (order 0), MRA
  carries <nvram index="2" size="2048"/> - so the FULL 2KB work RAM is
  dumped/restored via the NVRAM mechanism, commit 6a86cc3c0.
- Unknowns / next steps:
  1) Verify on MiSTer that the NVRAM file is actually written on exit
     and reloaded (needs OSD save enabled? jtframe NVRAM doc) - scores
     "not saved right now" may be a platform behaviour, not core logic.
  2) Restoring the whole 2KB (not just the battery-backed half) also
     restores volatile game state - check whether the game re-inits the
     volatile half at boot (likely, given the checksummed NVRAM restore
     code at boot) or whether we corrupt startup state.
  3) The boot code validates the NVRAM (S1 notes: restore-from-SD added
     precisely for this); if validation fails it wipes the table -
     an all-FF or zeroed file must still boot clean.
  4) MAME parity: mame monymony saves .nv len 0x800 - compare its file
     layout with our ioctl dump to confirm addressing matches.

## 6. audio very low

Since we did the mixer the overall volume is very low, something is normalizing us in hte low part

## 7. flip mode sprite shift

IN forced flip mode and in cocktail mode flip, the sprites needs to be moved around 2px on the right on the scaline