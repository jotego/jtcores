#### Audio output network (FM / SSG / VLM → mixer)

Three source paths are conditioned, then summed by the **LA6358 inverting summer**
(feedback **R3 10k**) and driven to the speaker by the LA4460. Each source enters
the summer through its own resistor — **FM→R6 3.3k, SSG→R7 5.6k, VLM→R8 3.3k** —
AC-coupled by a 4.7µF cap (C12/C13/C14). The three input blocks:

**FM — YM2203 OPN → YM3014 DAC → R6**
```
 YM2203 ──SCLK/SH/SD──► YM3014 ──MO──[4.7µ]──[R5 470]──► UPC324 buffer (×1)
        ──[C8 2200p]──► UPC324 buffer (×1) ──[R10 1k]──┬──[R9 1k]──[C12 4.7µ]──► R6 3.3k
                                                   [C17 0.033µ]
                                                       │
                                                      gnd
```
- both UPC324 are unity followers (no feedback R) → FM gain **×1**
- DC gain set by the series path **R10 + R9 + R6 = 5.3k**
- **C17** at the R10/R9 node → low-pass **≈ 6 kHz**
- **C8 2200p** has no feedback R → corner > 100 kHz, inaudible (ignored)
- → jtframe: `rsum 5.3k, rc {0.81k,33n}`

**SSG A/B/C — passive resistor mixer (no op-amp) → R7**
```
 CHA ──[R18 1k]──┬──[R21 2.2k]──┐
                 └[4066 D5]──[C22 0.15µ]──gnd
 CHB ──[R24 1k]──┬──[R20 2.2k]──┼── bus ──[R16 1k]──[C13 4.7µ]──► R7 5.6k
                 └[4066 D5]──[C20 0.15µ]──gnd
 CHC ──[R25 1k]──┬──[R19 2.2k]──┘
                 └[4066 D5]──[C21 0.15µ]──gnd
```
- each voice: **1k → 4066-switched 0.15µF to gnd → 2.2k → shared bus → R16 1k → C13**
- 4066s gated by **YM2203 IOA[2:0]**: closed = low-pass **≈ 1.4 kHz**, open = bypass
- symmetric → the three voices have **equal** gain; folded series ≈ **20k** each
- → jtframe: `rsum 20k, rc_en, dcrm, rc {0.78k,150n}` (×3, equal)

**VLM5030 speech — DAO → R8**
```
 DAO ──[C23 10µ]──[C25 0.1µ]──[R22 4.7k]──► UPC324 (R17 24k fb, gain ×5.1)
     ──► UPC324 (R13/R14 10k + C15 330p + C19 47n, 2nd-order LP) ──[C14 4.7µ]──► R8 3.3k
```
- block A: inverting gain ≈ **24k/4.7k = ×5.1**; C25+R22 high-pass ≈ 340 Hz (not modelled)
- block B: active **2nd-order low-pass ≈ 4 kHz**
- → jtframe: `rsum 3.3k, pre 5.1, dcrm, rc {10k,3.9n}×2`

**Final summer / `mem.yaml` mapping**

| source | enters via | rsum | pre | rc (low-pass) | dcrm |
|---|---|---|---|---|---|
| FM | R6 3.3k | 5.3k | ×1 | ~6 kHz (C17) | — |
| SSG ×3 | R7 5.6k | 20k | — | switched ~1.4 kHz (`rc_en`) | yes |
| VLM | R8 3.3k | 3.3k | 5.1 | ~4 kHz, 2nd-order | yes |

LA6358 feedback **R3 = 10k** = the top-level audio `rsum` (gain reference; it
normalizes out, so only the per-channel `rsum` *ratios* set the balance).

> **Caveat:** `rsum` within a source is exact, but the **FM-vs-SSG-vs-VLM
> balance is an estimate** — the FM/VLM op-amps and the SSG passive mixer scale
> differently, and the three chip modules have different digital full-scale
> levels. Expect to nudge the three `rsum` magnitudes by ear against a real
> recording; the SSG `20k` (a passive-ladder approximation) is the most likely
> to need adjustment.
