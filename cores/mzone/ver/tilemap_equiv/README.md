# Native FIX/SCROLL renderer simunit

From the repository root, with Verilator and Icarus on PATH:

```sh
source setprj.sh
export VERILATOR_ROOT="$HOME/github/verilator"
export PATH="$VERILATOR_ROOT/bin:$PATH"
simunit.sh --run cores/mzone/ver/tilemap_equiv
```

The `.simunit` marker lets the existing unit-simulation workflow discover the
test. No game ROM, MAME capture, or `JOTEGO` directory is required.

`reference/` contains frozen copies of the original custom renderers. Each
records its source SHA256. Do not regenerate them to make a candidate pass.
The DUTs now use `jtframe_tilemap` for FIX and `jtframe_scroll` for SCROLL.

Independent synchronous tile RAM and handshaken graphics ROM models drive each
instance. Codes, palette indices, bank bits and per-tile H/V flips vary by
address. ROM words have distinct pixels; all 256 character PROM entries and
32 mixer PROM entries are programmed with nonidentity data.

Both old and new outputs pass through separate instances of the actual
`jtmzone_colmix`, including its palette and blanking pipeline. Identical object
pixels exercise the delayed FIX-priority/source tails. This checks observable
RGB, rather than requiring unselected layer pixels or blanking fetch internals
to match. Unknown RGB/control outputs fail.

The Cartesian matrix has 512 scenarios:

- Pixel periods of 4 and 8 master clocks.
- Both global flip states and both video widths.
- Scroll pairs `(0,0)`, `(7,1)`, `(0x81,0x7f)`, `(0xff,0xff)`.
- ROM delays of 0, 8, 24 and 55 master clocks.
- Starting vertical counts 14, 238, 254 and 262. Count advances after H=319,
  HS is high at H=320–351, and V wraps after 263.

After one line of warmup per case, three entire lines are checked at every
master-clock falling edge:

| Check | Expected result | Count |
| --- | --- | --- |
| FIX source/priority and final H/V blanking | Exactly equal to frozen controllers, at all delays | 3,538,944 |
| Final RGB with ROM delay 0 or 8 | Exactly equal, no coordinate shift or color tolerance | 1,769,472 |
| Native helper shifter after a missed load deadline | Zero graphics bits until next load | 589,824 |
| SCROLL diagnostic | Reports the native helper's missed load boundary | Every checked clock |

ROM request phases are intentionally not compared: the helpers now own the
native fetch schedule. Their zero-fill policy differs from the original
retained-word fallback, so RGB equivalence is asserted only for timely
responses. The 24/55-clock cases still check controls, blanking, and actual
zero-fill behavior. Zero graphics bits are tested before palette lookup.

RAM contents and scroll/flip settings remain stable within each scenario.
This is not a formal proof for live CPU writes, mid-line register changes, or
reset transients. It does not validate the object renderer itself or replace
PCB comparisons. Scene 989 is also replayed separately; its settled frame is
pixel-identical, though initialization frames can differ with native timing.

A temporary candidate with character palette address bit 0 inverted was rejected
on the first checked visible line, confirming the RGB checker detects errors.
