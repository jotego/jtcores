# JTTAITOX — open items

## 1. Gigandes: 4-pixel purple dot on row 0

**Symptom.** Stray artefact on the first visible scanline: exactly 4 pixels at
columns 12–15, row 0 only, RGB (140,57,140). In simulation it appears on about
one frame in five and is gone on the very next frame. On real hardware it is
persistent rather than alternating.

**Reproduce.**

```bash
ROMS_HOST=~/mameroms FRAMES=200 ./sim-core.sh taitox gigandes
```

Then scan *every* written frame for lit pixels in row 0. Dot frames in a recent
run: 96, 97, 98, 100, 101, 122, 132, 138, 148, 150, 154, 171, 178, 192.
Compare frame 138 against 139 — the diff is 4 pixels, rows 0..0, cols 12..15.

Do **not** spot-check sparse frames. An earlier attempt sampled
1/214/249/487/610/645/940, hit no dot frames, and wrongly concluded the bug was
absent.

**Ruled out — the sprite Y wrap.** A wrapped 16-tall sprite would paint 8 rows,
not one. A/B on the actual dot frames:

| OBJ_YWRAP | dot frames | frames written |
|---|---|---|
| 0 | 96 97 98 100 101 122 · 138 · 150 154 171 178 192 | 73 |
| 1 | 96 97 98 100 101 122 132 138 148 150 154 171 178 192 | 77 |

Twelve are common to both, so the parameter neither creates nor removes it. The
runs are not bit-identical, so it does perturb something — just not this.

Also confirmed but not the cause: gigandes parks 474–480 of its 512 sprites at
Y=0xFA. With `yoff=+0x0e` that is row 248 plus a wrap copy at −8 covering rows
0..7, and ~40–45 carry non-zero codes — but they have transparent pixels in the
wrapped rows, so nothing is drawn.

**Leading theory — object line buffer at the frame boundary.** `jtkiwi_obj`
renders line N+1 while line N is displayed. At the top of a frame the
"previous" line is the last line of the *previous* frame, so leftover buffer
content can surface on row 0. Fits all three observations: one row tall, a few
pixels wide, varying frame to frame. Hardware showing it persistently while the
sim alternates suggests a race whose timing differs between SDRAM/BRAM and the
real board, not a deterministic logic error.

**Where to look.** `cores/kiwi/hdl/jtkiwi_obj.v` — how `jtframe_obj_buffer` is
cleared and swapped across vblank, and whether row 0 gets a full render slot
before being displayed. `VB_END=7` / `VCNT_END=271` in `hdl/jttaitox_video.v`
set where that boundary falls.

**Constraints.** Keep `OBJ_YWRAP(1)`: the X1-001 compares an 8-bit line counter
against an 8-bit sprite Y, MAME models the same via the `row−256` second
`transpen`, and cal50 and arbalest both set it. Any fix must keep superman
byte-identical to MAME on the title screen (frames 412/452/492) — that
comparison has already caught two real bugs.

## 2. `OBJ_YWRAP` conflates two behaviours

`cores/kiwi/hdl/jtkiwi_obj.v:106`

```verilog
if( hs || (!YWRAP && vdump>9'hf8) ) begin   // scanner reset
```

The parameter controls both the Y compare width *and* whether the scanner is
held reset through vblank. These are unrelated and should be separate
parameters. Shared module — needs cal50 and arbalest regression before landing.

## 3. Superman: stuck audio note in attract mode

A note hangs during attract, in the FPGA sim *and* in MAME.

**Reproduce.** No `.cab` — the bug is in attract, coining up skips it.

```bash
ROMS_HOST=~/mameroms FRAMES=7200 ./sim-core.sh taitox superman
```

**The 68000 is not the cause.** A write tap on the TC0140SYT master ports
(800000 port / 800002 comm) over 3600 frames of MAME attract gives 7433 writes,
of which only 126 are commands — the rest is a per-frame `port=4`/`port=0`
status poll. Commands arrive as a nibble pair (`cmd`, then `cmd>>4`), so the
first raw byte of each pair is the command:

| frame | command | on screen |
|---|---|---|
| 69 | port 4 = FF then 00 | Z80 reset asserted, released |
| 76 | `EF` | — |
| 77 | `00` | — |
| 805 | `05` | logo + copyright screen |
| 1516 | `62` | screen has just blanked, demo about to start |
| 1664+ | `1B`..`4C`, `62` … | demo gameplay SFX, 122 commands |

Between f805 and f1516 — the whole second title screen and the villain
"INSERT COIN" screen, ~12 s — the 68000 sends **nothing**. At the attract
transition it sends exactly one command, `62`, which is also the most frequent
command of the run (21x, recurring all through the demo) and so is an SFX, not
a music change. `00` is never sent again after f77.

So the driver is never told to stop the title tune; the tune ends on its own.
The hanging note is inside the `05` sequence's own tail, not a command the
68000 dropped or sent late. The mailbox is exonerated.

**Identified.** The repeating note is ADPCM-A channel 4 playing the sample at
`0x47800-0x4C600` of `b61-01.e18` (0x4E00 bytes = 2.16 s), re-triggered by
sound command `62`. The 68000 sends `62` at f1516 — the frame the screen blanks
for the demo — and then in bursts about 30 frames apart all through level 1
(f1733 1850 1880 1910 2030 2060 2082 2132 2180 2210 2330 … 3409), so a 2 s
sample is restarted twice a second until the high-score screen, when the sends
stop. Confirmed by decoding the sample and listening.

The whole chain (68000 game code → `62` → Z80 → ADPCM-A ch4) is deterministic
from the ROM, which is why MAME and the FPGA agree exactly. Not a sound-side bug:
neither the TC0140SYT mailbox nor jt10 does anything but obey. If a real PCB is
ever heard not to do this, the only place both MAME and the FPGA could differ
from it is what the 68000 reads on that path during the demo (C-chip, inputs) —
that would be a game-logic question, not an audio one. **Closed as authentic
behaviour unless a real board says otherwise.**

## 4. Twin Hawk sound code needs rework

`hdl/jttaitox_hawk_snd.v` works — Twin Hawk boots, renders and produces YM2151
audio — but the structure needs revisiting. Both chip sets are instantiated and
muxed on `p051a`, sharing one Z80; the idle mailbox is gated off via
`syt_mbox`/`hawk_mbox`. Open question is whether P0-051A belongs in this core
at all, given it also differs in visarea (224 lines against 240, giving 8 blank
rows top and bottom that become side bands after ROT270).

## 5. Video timings need measuring on an original board

`hdl/jttaitox_video.v` carries a `TODO` on the `jtframe_vtimer` parameters. The
grid we run is 512 x 272 at an 8 MHz dot clock: **15.625 kHz H, 57.4449 Hz V**.
It was chosen to land near 15.625 kHz (a lower H rate gives MiSTer HDMI vertical
stripes) and it matches MAME frame-for-frame, but no number in it comes from a
measurement.

What the sources actually say:

| source | H | V | note |
|---|---|---|---|
| driver PCB notes, East Tech P0-057A | 15.22 kHz | 58 Hz | measured on a real board, but *that* board |
| MAME `set_refresh_hz`, superman | — | 57.43 | software constant, no H at all |
| MAME `set_refresh_hz`, daisenpu / gigandes / ballbros | — | 60 | ditto |
| ours | 15.625 kHz | 57.4449 Hz | derived from 8 MHz / 512 / 272 |

15.22 kHz at an 8 MHz dot clock is 525.6 dots per line and 262 lines per frame,
against our 512 x 272 — so if that measurement is right for P0-039A too, both
our totals are wrong even though the picture matches MAME. The 60 Hz / 12 MHz
Z80 / YM2203 block further down the driver notes is a different board entirely
and should not be used.

**To measure on a real P0-039A:** dot clock at the X1-002/X1-003, HS period
(dots per line), VS period (lines per frame), and where HB/VB and the sync
pulses sit inside them. Also whether P0-051A really shows only 224 lines
(see item 4).

**Why it matters.** The V rate feeds back into the 68000: a vsync faster than
the board's livelocks Superman (60.1 Hz did). And every sprite-position
discussion so far — `OBJ_VOFF`, the whole-screen line shift seen on hardware —
has had to be argued against MAME because there is no board reference. Until
these are measured, keep `OBJ_VOFF` at 0: MAME is the only reference we have.

