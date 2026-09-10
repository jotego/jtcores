# Wardner whole-core bench

Runs `jtwardner_game.v` under jtcores' own `jtsim` harness, with the real
SDRAM controller and the C++ SDRAM model, so the thing being tested is the
core as it will be built rather than a hand-wired bench.

## Building the ROM

`mkrom.py <rom dir> wardner.rom` assembles the image the MRA is meant to
produce, following `cfg/macros.def` exactly. Put it in `$ROM/wardner.rom`.

Byte order inside a 32-bit word is not a guess: `jtframe_rom_2slots.v`'s own
self-check compares a read against `{ mem[a+1], mem[a] }` over 16-bit words
that load little endian, so the four bytes at increasing addresses land in
`data[7:0]`, `[15:8]`, `[23:16]`, `[31:24]`. The tile and sprite engines want
plane 0 in the low byte, so the planes are written plane 0 first.

## Running

```
cd $CORES/wardner/ver/wardner          # jtsim insists on a setname folder
jtsim -verilator -load -video 4        # full ROM download, dumps sdram_bank*.bin
jtsim -verilator -video 80             # later runs preload the banks, much faster
```

A fast run does not stream the ROM through the download, so the DSP mask ROM
never reaches its block RAM. Generate the two sim files once:

```
python3 - <<'PY'
rom=open('$ROM/wardner.rom','rb').read(); dsp=rom[0x048000:0x049000]
open('dsprom_lo.bin','wb').write(dsp[0::2]); open('dsprom_hi.bin','wb').write(dsp[1::2])
PY
```

## What it has established

- The core elaborates and simulates end to end, and reports **54.88 Hz**,
  which is Wardner's frame rate. That exercises the whole clocking chain:
  6 MHz from the 48 MHz clock, and the fractional 14 MHz halved to the 7 MHz
  pixel clock and again to 3.5 MHz.
- Every ROM region lands where `cfg/macros.def` says. Dumping the four SDRAM
  banks after a full download and comparing them against `wardner.rom`
  matches byte for byte across main, sound, DSP, char, bg, fg and sprites.
  The bank dumps store each 16-bit word big endian, so swap before diffing.
- **The core produces audio**, and it is the only bench that exercises
  jtframe's mixing path and the cabinet inputs. Both of those turned out to
  matter - see below.

## Audio, and the input polarity bug that was hiding it

The core makes sound, and it took two corrections to see it.

### Running it

```
jtsim -verilator -time 53000 -dipsw 1
```

`-time` takes board milliseconds and needs no video dump. Reaching the first
sound costs about 66 minutes at 0.0128 s of board time per wall second. The
run leaves `test.wav` (48 kHz stereo, written unconditionally by the harness)
and `opl_wr.log`, which jtopl writes with one line per register write.

**`-dipsw 1` is not optional.** jtsim defaults the DIP switches to
`FFFFFFFF`, and the core wires `{dipsw_b, dipsw_a} = dipsw[15:0]` straight to
port `50` with no inversion. MAME's XML for this machine says what those bits
are:

```
DSWA mask 0x04  Service Mode   Off=0x00, On=0x04
DSWA mask 0x08  Demo Sounds    Off=0x08, On=0x00
DSWA mask 0x01  Cabinet        default 0x01 (Upright)
```

so `FFFFFFFF` asks for **service mode on and demo sounds off**, and the game
correctly makes no sound at all. `1` is MAME's own default: DSWA `0x01`,
DSWB `0x00`. **Real hardware had the same fault until 2026-09-09**, though not
for this reason: `cfg/mame2mra.toml` carried an unconditional
`defaults = [{ value="ff,ff" }]` that overrode the correct `01,00` the
generator computes from MAME's own defaults. See section 18 of `doc/plan.md`.

### The bug

With the DIPs corrected the core still barely played: peak 11 in `test.wav`
and 16 key-ons over 53 s, where the subsystem bench had 68 by the same board
time and peaks of 4085. The cause was in `jtwardner_game.v`:

```verilog
assign cab_sys = { 1'b0, ~cab_1p[1], ~cab_1p[0], ~coin[1], ~coin[0],
                   dip_test, tilt, ~service };     // two missing inverters
```

The Toaplan SYSTEM port at `0x58` is a set of switch contacts that read high
when pressed, and jtframe hands the core its cabinet signals the other way up,
so each one needs an inverter. Seven had one; `dip_test` and `tilt` did not,
so the board saw the test switch held down and the tilt sensor tripped, for
the whole run. Both are active low: `jtframe_dip.v` says of `dip_test`
"assumes it is always active low" and drives it to zero to *assert* test under
`DIP_TEST`, and the CPS cores tie an unused `.tilt( 1'b1 )`.

The boot bench in `ver/main` could never have caught this: it drives `cab_sys`
from a plusarg that defaults to zero, so its test and tilt bits were clear by
accident.

### What it looks like fixed

| | DIP `FFFFFFFF` | DIP `1`, polarity broken | DIP `1`, fixed | MAME |
|---|---|---|---|---|
| `test.wav` peak | 0 | 11 | **3886** | 3962 |
| key-ons in 53 s | 0 | 16 | **163** | - |
| attack/decay writes (60-6f) | 0 | 0 | **16** | - |
| sustain/release writes (80-8f) | 0 | 0 | **16** | - |

The envelope registers are the tell. Until this fix no simulation of this core
had ever seen a single write to bands `60` or `80` - the zeros recorded in
this file's earlier version were the test switch, not the game. With it
released the driver programs envelopes and plays.

Against MAME 0.289 on the same window:

```
   time      core    MAME
  49.75s        0    3897
  50.00s     3732    3807
  50.25s     3886    3896
  50.50s     2278    3962
  50.75s     3799    3753
  51.00s     3745       0
  51.25s        1       0     both silent
```

On 10 ms RMS envelopes over 48-53 s the core **lags MAME by 320 ms** - 0.6%
over 50 s, which is real SDRAM latency against MAME's zero-wait memory - and
at that alignment they correlate at **r = 0.9762**. The `ver/main` bench, whose
program ROM answers in one clock, sits at zero lag instead.

`opl_wr.log` is written with `$fdisplay` and the harness exits from C++, so its
tail can be lost; treat a short log as no evidence either way. Its first field
is a line counter, not a timestamp.

## Frame images

`convert` (ImageMagick) is absent here, so jtsim cannot turn `frame.raw` into
a PNG. `raw2png.py frame.raw out.png 320 240 2` does the same job with only
the standard library. Note that jtsim writes `frame.raw` from a forked child
and only when a frame differs from the one before it.

## Environment notes

The cloud container this core was first built in needed two shims that a
normal machine does not: `envsubst` from gettext, and a `verilator` wrapper
dropping `--quiet-stats`, which Verilator 5.020 does not know. Neither
changed what was simulated. On gunmetal, with Verilator 5.052 and gettext
present, the stock harness runs unmodified.

`raw2wav` is a Go tool in `$JTUTIL/bin` and is not built here, so jtsim says
"Bypassing sound.raw conversion" and leaves the file alone. That is harmless:
`test.wav` is written directly by the Verilator harness at 48 kHz, and its
header is only finalised when the run ends - a WAV reader will reject it
mid-run, so read the raw PCM past the 44-byte header to watch progress.
