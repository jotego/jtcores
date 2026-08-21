# Dark Seal — annotated M68000 boot trace

Captured from MAME 0.276 (`darkseal`) via
`ver/darkseal/mame_scripts/trace_master_boot.mame`. The raw `.tr` (914k lines)
is `.gitignore`d; this file annotates the load-bearing landmarks + the stage-2
validation gates the FPGA PC stream must reproduce one-for-one.

> The trace engages at PC 0x1490 (MAME's debugger `go` started just after the
> 68000 reset vector fetch). The initial SP/PC come from the maincpu ROM
> vectors at 0x000000/0x000004 — read those if the exact reset PC is needed.

## First ~30 instructions (deduplicated through the loops)

```
; ---- control-register init ----
001490: move.w  #$1, $180008.l      ; soundlatch <- 1   (kick sound CPU)
001498: clr.w   $180006.l           ; sprite-DMA buffer clear
00149E: clr.w   $18000a.l           ; irq_ack clear

; ---- GATE 1: work-RAM clear 0x100000-0x104000 (16 kB) ----
0014A4: lea     $100000.l, A1
0014AA: moveq   #$0, D0
0014AC: move.l  D0, (A1)+           ; loop body
0014AE: cmpa.l  #$104000, A1
0014B4: bne     $14ac
0014B6: lea     $104000.l, A7       ; SP = top of work RAM

; ---- GATE 2: tilegen control init  (jsr 0x161C) ----
0014BC: jsr     $161c.w
00161C: moveq   #$0, D0
; tilegen[0] pf_control @ 0x2a0000:
00161E: move.w  #$53,   $2a0000.l
001626: move.w  D0,     $2a0002.l
00162C: move.w  D0,     $2a0004.l
001632: move.w  D0,     $2a0006.l
001638: move.w  D0,     $2a0008.l
00163E: move.w  #$8080, $2a000a.l
001646: move.w  #$8000, $2a000c.l
00164E: move.w  #$4101, $2a000e.l
; tilegen[1] pf_control @ 0x240000:
001656: move.w  #$90,   $240000.l
00165E: move.w  D0,     $240002.l
001664: move.w  D0,     $240004.l
00166A: move.w  D0,     $240006.l
001670: move.w  D0,     $240008.l
001676: move.w  #$8080, $24000a.l
00167E: move.w  D0,     $24000c.l
001684: move.w  D0,     $24000e.l
00168A: rts

; ---- GATE 3: sprite-RAM clear 0x120000-0x120800 (2 kB)  (jsr 0x2508) ----
0014C0: nop
0014C2: jsr     $2508.w
002508: move.l  A7, D5
00250A: move.l  #$1800000, D0       ; fill pattern in D0-D3
...    (4x)
002522: move.w  #$7f, D4            ; 0x80 iterations
002526: lea     $120800.l, A7
00252C: movem.l D0-D3, -(A7)        ; 4 longs/iter -> 0x800 bytes = 2 kB
002530: dbra    D4, $252c
```

## Validation gates (the FPGA PC stream must hit these in order)

1. **Gate 1 — work-RAM clear.** PC cycles `0x14AC → 0x14AE → 0x14B4` writing
   `0x100000..0x103FFC` then falls through to `0x14B6`. Easiest landmark; if the
   FPGA never reaches the `bne` loop, the address decoder for ROM (0x000000) or
   work RAM (0x100000) is wrong.
2. **Gate 2 — tilegen control init.** `jsr 0x161C` writes the two deco16ic
   control banks: `0x2a0000`(=0x53) for tilegen[0] and `0x240000`(=0x90) for
   tilegen[1], plus `0x_a`=0x8080 on both. Proves the tilegen chip-selects at
   0x2a0000 / 0x240000 decode.
3. **Gate 3 — sprite-RAM clear.** `jsr 0x2508` fills `0x120000..0x1207FF` via
   `movem.l` (0x80 iterations). Proves the sprite-RAM decode at 0x120000.

After these, boot proceeds to read inputs/DSW at 0x180000 (PC ~0x250A) and set
up palette pointers at 0x140a00/0x141a00 (PC ~0x256C).

## Notable register values (deco16ic pf_control, for reference)

| Reg        | Value  | Reg        | Value  |
|------------|--------|------------|--------|
| 2a0000 (t0)| 0x0053 | 240000 (t1)| 0x0090 |
| 2a000a     | 0x8080 | 24000a     | 0x8080 |
| 2a000c     | 0x8000 | 24000c     | 0x0000 |
| 2a000e     | 0x4101 | 24000e     | 0x0000 |

These are the initial tilegen mode/scroll-latch writes; capture the actual
runtime values with a watchpoint once the HDL tilegen is wired.
