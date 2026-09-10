# Schematic reconstruction - overnight autonomous run status

All 13 manual pages exist and load in KiCad 8 (open mnymny.kicad_pro; each
page also opens standalone). Connectivity is label-style (JOTEGO single-wire).
Review page by page against doc/sch/money_money.pdf (PDF page in parens).
Regenerate any page: python3 cores/mnymny/sch/gen/gen_<name>.py

## Page status
- video1 (p3)  WIRED   - counters, sync, flips, clock, palette, DAC complete
- video2 (p4)  WIRED*  - bg pipeline; LS194 grid D-bit taps + X-out naming to verify
- video3 (p5)  DRAFT   - line-buffer halves placed+labelled; LS86 compare pairs
                         (7A/8A, 7P/8P) unwired; 82S100 pin/net pairs to verify
- video4 (p6)  WIRED*  - customs (CTRL6J/6K boxsym) pin roles from scan; verify
- video5 (p7)  WIRED   - CN1, 9C mux, S0T/S1T gates, BK latch, /VIDOUT flop
- io1    (p8)  WIRED*  - Z80/buffers/decode/mainlatch/RAM+NVRAM/reset corner;
                         2F "333" chip and 5F gate from scan NOT placed yet;
                         watchdog analog loop simplified
- io2    (p9)  DRAFT   - 8255/controls/DIP banks placed+labelled; 24x diode
                         matrix NOT drawn (DIPSW8 blocks only); RC input
                         filters (20x1K + 220R + 0.1u per input) omitted
- io3    (p10) WIRED   - connector pinouts complete
- audio1 (p11) WIRED*  - 6802/PIA/2xAY/osc/decode; 4040 tap for CKGI + 4F
                         divider wiring to verify
- audio2 (p12) DRAFT   - all filter clusters placed with values + labels;
                         LM3900 sections placed as separate single-unit refs
                         (5B1/5C1... = sections of packages 5B/5C); TDA1510
                         pin roles need verifying against datasheet
- audio3 (p13) WIRED*  - speech CPU/PIA/TMS5200 (pins read from scan)/1408 DAC;
                         TMS5200 power pins unverified; filter passives partial
- rom1   (p14) WIRED   - sockets/PAL/CN1/CN2; 2732-vs-2764 strap jumpers not
                         drawn (see scan pads by pins 20/22); CN2 right-column
                         numbering partly uncertain
- rom2   (p15) WIRED   - four audio ROM sockets + CN3

## Global items for review
- Cross-sheet "(SHn)" nets are LOCAL labels; decide: global labels vs
  kunio-style hierarchical pins + root wiring.
- Power units of multi-gate packages not placed (kunio uses a capacitors
  sheet); ERC counts reflect this.
- 82S100 PLAs and 6J/6K customs are boxsym black boxes - net names best-effort.
- video1 flags from the first session remain (see git history of this file).
