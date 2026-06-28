# metafox boot trace (MAME 0.276 ground truth)

Captured with `ver/metafox/mame_scripts/trace_{main,sub}_boot.mame`. Raw `.tr`
files live in `ver/metafox/traces/` (gitignored, multi-MB). This file is the
annotated reference the FPGA PC stream must reproduce.

## Main 68000 (tag `maincpu`) — `traces/main_boot.tr`

Reset loads SP from `[0]` and PC from `[4]`; first executed instruction is at
**PC=0x000760**.

```
000760  lea     $f00000,A0          ; --- work-RAM clear loop ---
000766  move.l  #$0,(A0)+
00076C  cmpa.l  #$f04000,A0          ; work RAM = 0xf00000..0xf04000 (16 KB)
000772  bne     $766
000774  jmp     $8a000              ; -> 08A000 -> 08A8E8 main init
08A8E8  move.b  #$1c,$a00001        ; sub-ctrl off0  (bit0=0: no sub-reset pulse yet)
08A8F0  move.b  #$20,$a00003        ; sub-ctrl off2
08A8F8  move.b  $600003,$a00005     ; read DSW2 -> soundlatch0 (to sub, 0xa00004)
08A902  move.b  $600001,$a00007     ; read DSW1 -> soundlatch1 (to sub, 0xa00006)
08A90C  move.w  #$0,$200000         ; protection / twineagl region
08A914  move.b  #$18,$d00601        ; X1-001 sprite-ctrl (0xd00600-0xd00607)
08A91C  move.b  #$20,$d00603
08A924  move.b  #$0, $d00605
08A92C  move.b  #$ff,$d00607
08A934  move.b  #$40,$c00000        ; X1-001 bg-flag
08A944  move.b  #$0, $800005        ; X1-012 ctrl
08A94E  move.w  D0, $800000
08A954  move.w  D0, $800002
08A95A  move.w  #$0,  $700000       ; palette
08A962  move.w  #$123,$7003e0       ; palette test pen
08A972  movea.l #$f00000,A0         ; second work-RAM fill (incrementing pattern)
```

Confirms the `downtown_map` decode in `jtarbalest_main.v`: work RAM 0xf,
sub-ctrl 0xa, X1-001 0xc/0xd, X1-012 0x8, palette 0x7, DSW 0x6, protection 0x2.

## Sub 65C02 (tag `sub`) — `traces/sub_boot.tr`

Runs from machine reset (NOT held); reset vector -> **PC=0x7000**.

```
7000  sei / cld / ldx #$fd / txs    ; stack at 0x1fd
7005  lda #$00 / sta $00ff
700A  lda $1000 / and #$c0 / cmp #$c0 / beq ...   ; read COINS, check coin bits
7016  ...zero-page clear loop (0x00..0xfe)...
70C2  sta $5055                      ; --- write shared RAM (to main) ---
70C5  sta $5000
752B  lda $1002                      ; read P1
755D  lda $1006                      ; read P2
732B  lda $1000                      ; read COINS
```

Confirms the sub's role: read P1/P2/COINS (0x1000/1002/1006), publish to shared
RAM 0x5000-0x57ff. Matches `jtarbalest_sub.v` decode.

## Main <-> sub comm protocol (drives the shared-RAM bring-up)

From `sub_ctrl_w` (downtown.cpp) + the traces:

| Main side (68000)            | Sub side (65C02)        | Meaning |
|------------------------------|-------------------------|---------|
| `0xa00000` bit0 `0->1`       | `pulse RESET`           | restart sub to act on a command |
| `0xa00004` write             | read `0x0800`           | soundlatch0 (main -> sub) |
| `0xa00006` write             | read `0x0801`           | soundlatch1 (main -> sub) |
| read `0xb00000` (byte, LDS)  | write `0x5000-0x57ff`   | shared RAM (sub -> main) |

## FPGA validation gates (diff against this)

1. Main reset entry **0x760**, work-RAM clear `0xf00000..0xf04000`.
2. `jmp 0x8a000 -> 0x8a8e8`, then the `0xa0000x` sub-ctrl/soundlatch writes.
3. X1-001 / X1-012 / palette init writes (above).
4. Sub boots to **0x7000**, reads inputs, writes shared RAM 0x5000.
5. Main reads shared RAM at 0xb00000 and proceeds past input polling.

## Scaffold deltas the trace exposes (next HDL work)

- `jtarbalest_main.v`: `subctrl_cs` must decode offsets — `0xa00000` bit0 = sub
  RESET pulse, `0xa00004/6` = soundlatch writes. Currently a single bundle.
- `jtarbalest_sub.v`: wire the soundlatch reads (`0x0800/0x0801`, `lat_cs`),
  currently unconnected.
- Work RAM is 16 KB (0xf00000-0xf04000) — `mem.yaml` `ram` addr_width 16 is ample.
- Sub is free-running from reset (no reset gating needed); the `0xa00000` reset
  pulse is a re-sync, refine once the handshake is exercised.
