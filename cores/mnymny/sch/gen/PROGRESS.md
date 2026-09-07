# Schematic reconstruction progress (autonomous overnight run)

Review page by page against doc/sch/money_money.pdf (PDF page in parens).

## video1 (p3) - PLACED + WIRED (draft)
Uncertain/flagged for review:
- 4L CEP(7): wired HTC1 like CET; PDF may tie it to 1H instead.
- 5N u2 /LD2 gate inputs: wired 1H,2H + 4H-inverted (5K u2); verify pins 3/4/5 roles.
- 6G/6L /VIDOUT gating inputs (HBLANK/VBLANK/CBLANK*) - verify order.
- 9E/9D mux input/output assignment PA3..PA8 order vs PDF verticals.
- 9M CF1-4 buffer outputs labeled CF1O..CF4O; PDF mixes them onto RGB via
  R14-R17 - exact gun per resistor unverified.
- Power units of multi-gate packages not placed (hidden power pins float);
  decide whether to add a power/decoupling area like kunio capacitors sheet.
- Cross-sheet nets are LOCAL labels for now; "(SHn)" nets should become
  global labels or hierarchical pins - decide style.
