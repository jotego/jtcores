# 54.432 / 108.864 feasibility (pixel x9 family)

Asset: modules/jtframe/target/mister/hdl/pll6048m9 - pll6048 transposed
x9/8: 54.432 base pair, 27.216, 6.048 pixel (unchanged), 108.864 fast pair.
Fractional VCO like pll6048 (54.432/50 has no small integer ratio; pll7000
is integer only because 56/50 = 28/25). Shifted-pair phase fractions kept
from the donor (0.2688 and -0.4871 of the respective periods). NOT wired.

## What it buys over 48.384/96.768

+12.5% on every budget at unchanged video timing: 3456 clocks/line
(vs 3072), the C355 scanner (the measured obj bottleneck: sstall ~190k vs
fstall ~60k) runs 12.5% faster, SDRAM bandwidth +12.5%.

## Wiring (all plumbing already exists from the 60 MHz era)

JTFRAME_PLL=jtframe_pll6048 keeps the pixel-frequency name parse (6.048);
JTFRAME_BASE_MUL=9 makes mclk 54.432 and drives pllsim. Needed additions:
files.yaml qip selection must learn the MUL dimension (pll6048 vs
pll6048m9), and jtframe_pxlcen's M table needs the n=2/m=9 fractional pair
(M=BASE_MUL/2 breaks on odd MUL). Cen ratios on the base: cpu 10/27
(20.16), xin 8/27 (16.128), c352 4/9 (24.192) - exact PCB rates preserved.

## Closure assessment

- Core logic at 18.37 ns: PROVEN - the honest (waiver-free) integer-60
  build closed at 16.53 ns with +0.259 slack (885d37e3c era). 54.432 is
  strictly easier than a configuration that already passed the fitter.
- SDRAM domain at 9.19 ns vs 10.33 today: jtframe boundary/shim cones are
  short; the pll6144 fleet proves the controller at 98.3 MHz and cps3's
  burst subsystem runs 112, so 108.9 sits between mileage points, not
  beyond them.
- THE ONE REAL BLOCKER, -75 grade tRP/tRCD: at 96.768 a 2-cycle command
  interval is 20.67 ns >= 20 (legal for every grade - part of why 96 works
  so well). At 108.864, 2 cycles = 18.37 ns: legal for -7E (15) and -6A
  (18, marginal), ILLEGAL for -75 (20). Shipping 54/108 under the
  slowest-grade assumption requires a 3-cycle option in the HF=1 command
  path (F1 covered the LF path only) - a small jtframe_sdram64_bank change
  plus the same rw_test spacing proof at the 9.19 ns period.
- clk24 consumers get 27.216 (+12.5%): audit jtframe users (OSD etc.)
  before switching; sysfl's own cens all derive from the base.

## Verdict

Feasible with two contained patches (pxlcen odd-MUL, HF-path 3-cycle
spacing) and one audit (clk24). Do it only if the 48/96 bench leaves the
scanner-bound obj cuts as the pain point: 54/108 is the clock-axis answer,
the decoded-sprite-list rework is the architecture-axis answer, and the
two are independent.
