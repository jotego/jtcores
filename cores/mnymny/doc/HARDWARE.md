# Money Money hardware facts

Verified against the 1B11140 schematics (doc/sch) and the traced counter
presets. See doc/sch/*.md for the per-board digests and doc/pld/equations.md
for the dumped PLD logic.

## Video timing

| Item | Value | Source |
|------|-------|--------|
| Pixel clock | 6.144 MHz (18.432 XTAL / 3, LS107 at 2M) | sheet 1/5 |
| Line | 384 clocks (H counter 128..511) | 3L free-runs (/LOAD=VCC), 4L reloads at 4 |
| Frame | 264 lines (V counter 248..511) | 3N presets GND,GND,VCC,VCC; 4N VCC,VCC,VCC,GND |
| Visible | 256 x 224 (V 256..479) | 256V=1 during display |
| VSYNC | 8 lines, vdump 8..15 (V 248..255) | /VSYNC = 4N pin 11 (QD, 256V) directly |
| VBLANK | 40 lines: sets at V=496, clears at V=272 | 5P LS74 samples 5N NAND(32V,64V,128V) on 16V edges |
| Visible rows | V[7:0] = 16..239 (vdump maps directly) | from the 5P set/clear points above |
| HSYNC | 32 clocks, H 176..207 (vtimer 0x130..0x150) | 5J NAND(32H,/64H) -> 5M-1, CK=16H; /PRE masks the display half |
| V counter clock | 5M-1 /Q, once per line at H=176 | 2L toggles 1V, 3N/4N step every 2nd line |
| Refresh | 60.606 Hz (6.144e6 / 384 / 264) | |

VSYNC sits at the end of blanking (32-line front porch, no back porch).
jtframe_vtimer mapping: vdump = V - 240, VB_START=239, VB_END=15,
VS_START=8, VS_END=16.

## Clocks

| Clock | Value | Source |
|-------|-------|--------|
| Z80 | 3.072 MHz (18.432/6) | 1Hu from the video board, CN1-26 |
| 6802 x2 (audio) | 3.579545 MHz XTAL, E = 894.9 kHz | audio sheet 1/3 |
| AY-3-8910 x2 | 1.7898 MHz (3.579545/2, 4040 at 5F) | audio sheet 1/3 |
| TMS5200 | 649.2 kHz (RC osc R19 100K / C24 22pF) | audio sheet 3/3 |
| Melody PIA CB1 | 3.579545 MHz / 8192 = 437 Hz | 4040 + LS74 |
