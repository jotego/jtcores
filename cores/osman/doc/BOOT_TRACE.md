# Osman — ARM boot trace (main CPU spine validation)

MAME (ground truth) vs FPGA, DE156 ARM (`maincpu`). Reproduce with:
- MAME: `mame osman -debug -debugscript ver/osman/mame_scripts/trace_arm_boot.mame -seconds_to_run 1`
  → `/tmp/osman_arm.tr` (trim head → `ver/osman/traces/arm_boot.tr`).
- FPGA: `FRAMES=30 ROMS_HOST=~/.mame/roms-local ./sim-core.sh osman osman`
  → `ver/game/osman_arm_fpga.tr` (SIMULATION dumper in `jtosman_main.v`).
- Diff: `ver/osman/verify_arm_boot.sh` (MAME PCs must be an in-order subsequence of the FPGA
  fetch stream — ARM prefetch + literal-pool loads make the FPGA stream a superset).

## Status: ✅ BOOTS — matches MAME through the memory-clear loop (1600 PCs, subsequence-clean).

## THE fix — 32-bit ROM byte order
The `maincpu` region is `width=32, reverse=true`, but the assembled SDRAM bank holds the ROM in
natural byte order and the FPGA reads a 32-bit word as `{hi16, lo16}` with **each 16-bit half
byte-swapped** vs MAME's little-endian `uint32` view. deco156 needs the LE32 word, so `jtosman_main`
swaps bytes within each half before the decrypt:
```
rom_raw = { rom_data[23:16], rom_data[31:24], rom_data[7:0], rom_data[15:8] };
```
Verified offline (Python replica of MAME `decrypt()`): `dec(word 0) = ea000169`. A full 32-bit
reverse (the first guess) and the raw word both give garbage — it must be the per-halfword swap.

## Landmarks (decrypted PCs)
```
0000000: ea000169   B 0x5AC          reset vector -> boot
0000004..0000018    B ...            exception vectors (0x18 = IRQ -> 0x110)
00005AC: e51fd4b8   LDR R13,&0xFC    SP init  (0xFC -> 0x00201200 = systemram top)
00005B0: e51f84c0   LDR R8, &0xF8    (0xF8 -> 0x00201000 = systemram base)
00005B4: e33ff3c2   TEQP R15,#...    set mode/flags
00005C0: e3a00c01   MOV R0,#0x100    clear count = 256
00005C4: e3a01000   MOV R1,#0
00005C8: eb0014f5   BL 0x59A4        -> memory-clear loop
00059A4: STRB R1,[R9],#1             ] clear loop
00059A8: SUBS R0,R0,#1               ]  (256 iterations)
00059AC: BNE 0x59A4                  ]
00059B0: ...                         loop exit -> post-clear init (0x5CC ...)
```

## Validation gates
1. [x] reset vector decrypts (`0x0 = B 0x5AC`) — deco156 + ROM byte order correct.
2. [x] SP/mode init at 0x5AC, literal-pool loads read systemram addresses (0x201xxx).
3. [x] memory-clear loop 0x59A4 runs (BL, STRB writes, SUBS/BNE) — bus + work RAM correct.
4. [ ] post-clear init past 0x5CC into device setup (deco16ic/OKI/EEPROM writes).
5. [ ] first VBL IRQ taken (vector 0x18 -> 0x110) — needs real LVBL from the video vtimer.

## Notes
- deco156 word index = `wb_adr[18:2]` (512 KB = 17-bit; `a[17]=0`). Address scramble reads
  SDRAM word `0x92c6` for PC 0, etc. — spatial locality destroyed (why nslasher added a ROM cache;
  we don't yet).
- IRQ is stubbed to `vbl = ~LVBL` and LVBL is currently tied high in the video stub, so gate 5
  waits on the video timer (step 3).
