# PLD equations — Money Money

Decoded with `jedutil -view` from the Caius dumps (May 2017). The raw JED
files are not committed; only the equations and pin maps are kept here.
Signal names follow the schematic sheets (video board sheet 4/5 for 6J/6K,
ROM module sheet 1/2 for 1A).

## 1A — protection PAL, ROM board 1B11147

Dump is a GAL22V10 replacement for the original PAL16L8 ("unable to fit
equations into device" — original had product terms per output the 16V8
cannot host). Install note from the dumper: *tie pin 10 to pin 12 when
installing*: the 24-pin 22V10 sits top-aligned in the 20-pin socket
(22V10 pin n = socket pin n for n<=10, 22V10 pin n+4 = socket pin n for
n>=11; the 22V10 GND pin 12 hangs out and must be strapped to socket GND
arriving at 22V10 pin 10).

Socket (PAL16L8) pin map from the schematic:

| pin | net  | 22V10 pin | jedutil | dir |
|-----|------|-----------|---------|-----|
| 1   | AB1  | 1  | i1  | in |
| 2   | AB2  | 2  | i2  | in |
| 3   | AB9  | 3  | i3  | in |
| 4   | AB10 | 4  | i4  | in |
| 5   | AB11 | 5  | i5  | in |
| 6   | AB12 | 6  | i6  | in |
| 7   | AB13 | 7  | i7  | in |
| 8   | A14  | 8  | i8  | in |
| 9   | /RDB | 9  | i9  | in |
| 10  | GND  | 10(+12) | — | — |
| 11  | /WRB | 15 | i15 | in |
| 12  | DBB7 | 16 | o16 | out |
| 13  | /RFSH| 17 | i17 | in |
| 14  | n.c. | 18 | o18 | out (unused) |
| 15  | n.c. | 19 | o19 | out (unused) |
| 16  | DBB3 | 20 | i20 | in |
| 17  | DBB4 | 21 | o21 | out |
| 18  | DBB5 | 22 | o22 | out |
| 19  | DBB6 | 23 | o23 | out |
| 20  | VCC  | 24 | — | — |

R1/R2 (27K) pull up /RFSH and A14 respectively (confirmed on sheet): the two
inputs used in the OE terms are deasserted-high when the bus is not driven.

Equations (pin-level, schematic net names; `/x` = net low):

    RD64   = /AB9 & AB10 & /AB11 & /AB12 & AB13 & A14 & /nRDB         ; read 6400-65FF
    RD6C   = /AB9 & AB10 &  AB11 & /AB12 & AB13 & A14 & /nRDB         ; read 6C00-6DFF
    DBB4   = AB1 XNOR AB2                oe = RD64 & nRFSH
    DBB5   = AB2                         oe = RD64 & nRFSH
    DBB6   = /( /AB1 & AB2 & AB11 )      oe = (RD64|RD6C) & nRFSH
    DBB7   = 1                           oe = RD6C

    ; unused outputs (socket pins 14/15 n.c.), kept for reference:
    ; /o18 = AB1 & /AB2 & /AB9 & AB10 & /AB11 & /AB12 & AB13 & A14 & nRDB & /nWRB & /DBB3 & /DBB4 & DBB5
    ;      + AB1 & /AB2 & /AB9 & AB10 & /AB11 & /AB12 & AB13 & A14 & /nWRB & /nRFSH & /DBB3 & /DBB4 & DBB5
    ; /o19 = large sum using nWRB/nRFSH/DBB3 and DBB4/DBB5/DBB7 feedback (write terms)
    ; o18/o19 reference write strobes and data feedback: the original PAL had
    ; latch-like behaviour on internal nodes. Since both pins are unconnected
    ; on this board, they do not affect the bus.

Cross-check vs MAME prot1_r/prot2_r: D6 at 6400 (offsets 0/4/6 all read 1)
matches 0x50/0x40/0x70. At 6C04/6C06 the equations give D5/D6 values that
differ from MAME's traced constants — the dump is ground truth; MAME's
constants likely cover only the bits the game actually tests. Undriven bits
float (no pull-ups on DBB4-7): the core drives 0 for them, matching what
MAME returns. To be validated in boot simulation.

## IC6J — CONTROL LOGIC 1, video board 1B11140 (GAL16V8 drop-in)

| pin | net | | pin | net |
|-----|-----|-|-----|-----|
| 1 | GND (out enable) | | 12 | LDCOL3H |
| 2 | 1H  | | 13 | /BIT80 (6H inverter -> BIT80) |
| 3 | 2H  | | 14 | /CNTCLR |
| 4 | 4H  | | 15 | /CNTLD |
| 5 | /ABLOAD | | 16 | /CNTLDT2 |
| 6 | /256Hx  | | 17 | /CNTLDT1 |
| 7 | SELECT  | | 18 | /YB |
| 8 | 8H      | | 19 | /YA |
| 9 | /256H   | | 20 | VCC |
| 11 | /256H* (also sheet 3, 8N pin 22) | | 10 | GND |

    (raw jedutil form, i<n> = level on pin n; see pin table for net names
     and polarities, e.g. i6 = the /256Hx net, i8 = 8H):
    /o12 = i2&i3&i4&/i6&/i8 + i2&i3&/i4&i6&/i8
    /o13 = i3&i9
    /o14 = i2&i3&i4&/i8&i9&/i11
    /o15 = i2&i3&i4&/i8&/i9 + i2&i3&/i4&/i8&i9
    /o16 = i2&i3&i4&/i6&/i7&/i8&/i9 + i2&i3&/i4&i6&i7&/i8
    /o17 = i2&i3&i4&/i6&i7&/i8&/i9 + i2&i3&/i4&i6&/i7&/i8
    /o18 = i2&i3&/i4&/i5&i6&i7 + i2&i3&i4&i5&i6&/i7 + i2&i3&i4&/i5&/i7
    /o19 = i2&i3&/i4&/i5&i6&/i7 + i2&i3&i4&i5&i6&i7 + i2&i3&i4&/i5&i7
    all outputs enabled by pin 1 = GND

## IC6K — CONTROL LOGIC 2, video board 1B11140 (GAL16V8 drop-in)

| pin | net | | pin | net |
|-----|-----|-|-----|-----|
| 1 | 256H* | | 12 | WT2 (5K inv + 6L nand /6MHz -> R//WT2) |
| 2 | 1H  | | 13 | /LPREPF (6H inverter -> LPREPF) |
| 3 | 2H  | | 14 | /LPFMSW |
| 4 | 4H  | | 15 | CKOKVER |
| 5 | 8H  | | 16 | /OBDLOUT |
| 6 | /256H | | 17 | WT1 (5K inv + 6L nand /6MHz -> R//WT1) |
| 7 | /ABT  | | 18 | /VPL |
| 8 | /X123 | | 19 | /COLL1 |
| 9 | SELECT| | 20 | VCC |
| 11 | /X456| | 10 | GND |

    (raw jedutil form, i<n> = pin n level, o12/o17 active high:)
    o12  = /i1&i2&i3&i4&/i6&/i9&i11 + i9&i11 + /i1&/i2&i3&i11 +
           /i1&/i4&/i9&i11 + i1&/i6&/i9 + /i1&/i3&/i9&i11
    /o13 = /i3&i4&/i5&/i6&/i7 + i3&i4&i5&i6&/i7
    /o14 = /i3&i4&/i5&/i6&/i7 + i3&/i4&i5&i6&/i7
    /o15 = i3&i4&/i5&i6&/i7 + /i3&/i4&/i6&/i7
    /o16 = i3&/i4&/i5&/i6&/i7 + i3&i4&i5&i6&/i7
    o17  = /i1&/i2&i3&i8&i9 + /i1&/i4&i8&i9 + i1&/i6&i9 + /i6&i8 +
           /i1&/i3&i8&i9 + i8&/i9
    /o18 = /i3&/i4&/i7
    /o19 = /i3&i4&/i7
    all outputs permanently enabled

These two devices are the object-engine sequencing: to be used when the
object section is rebuilt schematic-exact (line-buffer fill per sheets 3/4).
Until then the behavioural scanner approximates them.
