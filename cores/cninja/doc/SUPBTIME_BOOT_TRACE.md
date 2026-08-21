# Super Burger Time — annotated 68000 boot trace

Source: MAME `supbtime`, `ver/supbtime/traces/master_boot.tr` (full per-instruction
trace from reset; raw .tr is gitignored). Capture:

```
mame -rompath ~/.mame/roms-local supbtime -debug \
  -debugscript cores/supbtime/ver/supbtime/mame_scripts/trace_master_boot.mame \
  -nothrottle -video none -seconds_to_run 1
```

## Reset vector

```
SSP = 0x104000   (top of work RAM, 0x100000-0x103fff)
PC  = 0x000734
```

## Boot landmarks (the FPGA PC stream must reproduce these)

```
000734  (entry)
00073A  move.w  $18000c, D0        ; read I/O (0x18000a-d is nopw region; status/dummy)
000740  move    #$2700, SR         ; mask all IRQs during init
000744  clr.l   D0
000746  movea.l #$100000, A0
000746..000754  CLEAR LOOP         ; move.l D0,(A0)+ ; cmpa #$140000,A0 ; bcs
        -> zeroes 0x100000-0x140000 (work RAM + sprite RAM + nopw gap). 0x10000 iters.
000756  movea.l $0.w, A7           ; reload SP from vector 0 (=0x104000)
00075A  move    #$2400, SR         ; enable IRQ levels 5 and 6
00075E  (IRQ 6 taken)              ; VBLANK IRQ -> handler

000DEE  movem.l D0-D7/A0-A6,-(A7)   ; *** IRQ6 = VBL handler ***
000DF2  tst.w   $100000            ; init flag
000DFA  jsr     $D9E               ; ack + I/O poke
000D9E  clr.w   $18000a            ; *** VBL IRQ ACK (read/clr 0x18000a) ***
000D4C  move.w  #$1, $18000c       ; (nopw) toggles a watchdog/coin-counter-ish reg
000DFE  move.w  $10301c, $300008   ; write deco16ic control reg (0x300008)
000E26  move.w  $180008, D0        ; read SYSTEM (coins/service/vblank bit3)
000EC0  btst    #$3, $100011       ; ...
```

## Validation gates (stage-2 FPGA sim must hit, in order)

1. PC=0x734 reset, SSP=0x104000.
2. `move #$2700,SR` at 0x740.
3. Clear loop 0x746-0x754 runs to A0=0x140000.
4. `move #$2400,SR` at 0x75A (IRQ enable).
5. First IRQ6 entry at 0x0DEE (VBL).
6. VBL ack via `clr.w 0x18000a`; deco16ic control write to 0x300008.

## Notes for the HDL

- **VBL -> IRQ6** (autovector level 6). Ack = write (clr) to 0x18000a (a *read* of
  0x18000a is `vblank_ack_r` in MAME; the handler does `clr.w 0x18000a`, a write to
  the same window — wire the ack on access to 0x18000a).
- No decrypt, no protection: maincpu ROM is read straight.
- The init clear loop touches 0x100000-0x140000 → work RAM (0x100000), sprite RAM
  (0x120000) and palette boundary must be BRAM and respond at CPU speed.
- 0x18000c writes are nopw (ignored); reads return a don't-care (the handler uses
  them as scratch/delay). Returning 0 should be safe — confirm if boot diverges.
