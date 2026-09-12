# Wardner main CPU — boot bench

`cores/wardner/hdl/jtwardner_main.v`: Z80 at 6 MHz, ROM banking, the two LS259
addressable latches, the I/O port map, work / sprite / palette / sound-shared
RAM, and the three tile maps behind their address-latch and data-port pair.

## What this bench does

`./run.sh <dir with the wardnerb ROM set>` builds the main program region and
the DSP's mask ROM from the real set, runs the boot sequence with the DSP
subsystem attached, and reports which milestones the game reaches. There is no
reference model at this level: every statement below is the game's own
behaviour, observed.

### The bench runs the board 2.381 times fast, on purpose

The clock enables keep the board's ratios exactly - 1/7, 1/3, 1/6 and 1/12 of
the reference give 6, 14, 7 and 3.5 MHz in the right proportion - but the
reference itself is 100 MHz where those dividers describe 42, because
`always #5` with a 1 ns time unit is a 10 ns period. So the whole board runs
100/42 = 2.381 times faster than the real one, uniformly. Every ratio is
preserved, the game behaves identically, and only the time axis is compressed,
which is the difference between reaching attract mode in an hour and not
reaching it at all. **Every millisecond this bench prints is a bench
millisecond; divide by 0.42 for board time.** The milestone lines give both.

The whole-core bench in `ver/game` uses jtframe's real clocking and is not
affected; its seconds are board seconds.

### Snapshots

`+snap=<ms>[,<ms>...]` freezes the main CPU at each of those bench
milliseconds in turn, dumps every video RAM into `snap<ms>/` for
`ver/video/run.sh`, and lets the game run on; the run ends after the last one.
Each freeze costs the game about 55 ms of bench time, so later targets drift
by that much.

Until 2026-09-08 the delay was computed as milliseconds times 1e6 in 32-bit
arithmetic, which wraps above 4295 ms: `+snap=14000` froze the game at 1115 ms
and `+snap=22000` would have frozen it at 525 ms. Snapshots taken before that
fix are earlier in the game than their names say.

`probe.v` counts bus activity by region so that a long stall can be attributed
to what the CPU is actually doing rather than guessed at.

## What the boot sequence shows

The first instruction in the ROM is `LD A,$04; OUT ($5C),A`, which selects
output 2 of the mainlatch and clears it - the vertical blanking interrupt is
disabled before anything else happens. That is the first thing the bench sees,
which is the cheapest possible confirmation that the Z80 is running real code
through a correct memory map.

Then, in order:

1. The HD6845S is programmed through ports 00 and 02.
2. Roughly 4.7 million cycles of power-on memory test: about ten passes over
   work RAM, nine over palette RAM and ten over the RAM shared with the sound
   CPU, counted by `probe.v`.
3. `OUT $5A,$01` sets the DSP run bit. The Z80 then stalls for 26.9 us -
   about 161 cycles at 6 MHz - before its next port write, which is the DSP
   taking the bus, doing its work and releasing the HALT line again.

Step 3 is the phase 3 gate: the real main CPU and the real DSP program complete
a handshake with each other.

After that the game finishes its power-on tests - one full pass over sprite
RAM, nine over palette RAM - enables the display, and runs. Over six seconds of
simulated time (about 330 frames) it issues:

```
  14339 writes to port 70   bank switching into the object ROMs
   8192 writes to ports 62/63 with 8193 address latches on 24/25   background map
   4096 writes to ports 64/65 with 4096 address latches on 34/35   foreground map
   2066 writes to port 61                                          text map
  40960 writes to sprite RAM
```

along with `5c,09` to bank the background map, and the display toggling off and
on between screens. That is the attract sequence: the CPU is filling all three
tile maps and sprite RAM, frame by frame.

Two things are worth recording because they cost time to establish. Through
that phase the vertical blanking interrupt is never enabled - the game polls
port 58 bit 7 instead - and the DSP is invoked once, at boot, and not again.
Both are simply what the software does there; neither is a fault in the
hardware model. MAME's LS259 fires its callbacks only when a bit actually
changes, so the run bit staying high after that first poke is correct
behaviour, not a missed retrigger.

**Both change once the game reaches attract mode**, which a run has to be about
30 bench seconds long to see. Over such a run the bench reports the vertical
blanking interrupt being enabled at 13000 bench ms (31 s of board time), the
bank window being read for the first time (158709 reads, so the game is running
code out of banked ROM), and the DSP halting the main CPU for 51004344 clocks
in total rather than the 253276 of the boot handshake. That last figure is the
DSP doing what the hardware notes say it does: driving enemy fire, collisions
and sprite placement continuously during play, not just answering once at
power-on.

### A note on run length

Every anomaly seen while building this bench turned out to be a run that
stopped too early. Sprite RAM appeared never to be written, then showed 4096
writes at two seconds and 40960 at six. The video RAM ports appeared never to
be used, then showed 28708 writes. Give a run at least four seconds of
simulated time before drawing conclusions from what is missing.

Attract mode raises that bar a lot further. The high-score table appears at
16000 bench ms, the attract demo plays from about 20000, and the title screen
is at 30000 - 38, 48 and 71 seconds of board time. A 31000 ms run takes about
65 minutes of wall clock at 7.7 ms of simulated time per second, and needs
`MAXIO` raised well above its 200000 default: such a run issues 1482049 port
writes, so the default cap would end it after about four seconds of attract.

## The sound CPU

`jtwardner_sound.v` is the audio side: a Z80 at 3.5 MHz with a YM3812 on ports
00 and 01, both from the 14 MHz crystal. It has no sound latch and no NMI - the
two processors talk only through the 2 KB window at C000, whose second port the
main CPU module already exposed.

The boot handshake is visible in the sound ROM's first instructions:

```
2b1d  di / im 1
2b20  ld (C000),$FF          announce itself
2b25  ld (C002),$00
      ld a,(C002) / sub $AA / jr nz   wait for the main CPU
```

Observed: the main CPU finishes its power-on tests and writes `AA` to C002 at
1000 ms, the sound CPU comes out of that loop, and from there both directions
carry traffic - 891779 shared reads and 229288 shared writes from the sound
side - while the YM3812 takes **34572 register writes** in the first two
seconds.

This corrects a note made during phase 3. The main CPU's reads of the shared
window match its writes, which looked like a fire-and-forget command channel;
that was true of the main CPU alone and did not describe the link. The sound
CPU is the side that polls, and it will not start until the main CPU answers.

## Audio

`+wav` captures every YM3812 output sample to `snd.raw`, signed 16-bit little
endian, and `raw2wav.py` wraps it for playback. `+fmlog=N` sets how many
register writes are logged to `boot.log`; the old hardcoded 400 all landed
around 1.3 s and could say nothing about later.

The bench also watches for a note being keyed on. The chip takes a register
address on port 0 and its value on port 1, so the address has to be remembered
to know what a data byte means; registers B0-B8 hold block and F-number for the
nine channels and bit 5 is that channel's key-on, the one write that makes the
chip audible at all.

A 28000 ms run (66.7 s of board time):

```
tb_main: first key-on at 20924 bench ms (49819 ms of board time), reg b5 = 3e
  YM3812 writes         : 790391
  note key-ons          : 288, first at 20924 bench ms (49819 ms board)
  audio samples         : 3240740, 1194990 non-zero, peak |snd| = 8158
                          48611 Hz at board speed
```

48611 Hz is exactly 3.5 MHz / 72, so the whole sound clock chain from the
14 MHz crystal to the chip's output rate is right by measurement rather than by
construction.

### Against MAME

MAME 0.289 running the same set headless is **silent for its first 49.5
seconds**, then produces discrete bursts with gaps - attract-demo sound
effects, not music. That is why every earlier sim found silence: they all
stopped tens of seconds of board time short of the first sound. Quarter-second
peaks over the active window:

```
   time      RTL    MAME
  49.50s       0       0
  49.75s    4075    3897     first burst, in both
  50.75s    2851    3753
  51.00s       1       0     both silent
  53.25s    4085    4639
  55.00s    3903    3867
  58.25s    4085    4043
  60.50s    4085    4076
  61.50s    8158    8480     the loud one, in both
  63.00s       2       0     both silent through 66 s
```

On 10 ms RMS envelopes across 49-63 s the two correlate at **r = 0.946, and
the best alignment is zero lag**, not a shifted one. They agree on which frames
are silent for 1328 of 1401 points.

Capturing MAME's audio needs `-noreadconfig -nowriteconfig`: a cfg written
while a dummy audio driver was in use pins the mixer to a node that no longer
exists, after which MAME exits instantly with status 0 and no message.

### The one difference, unresolved

Peaks agree within 3 to 13%, but the RTL's RMS is 1.2 to 1.9 times higher per
burst and it spends more time above 10% of peak, so its waveform carries more
energy between the peaks. Three candidates, not separated here:

1. MAME 0.289 applies a default audio effects chain - the cfg it writes lists
   Filters, Compressor, Reverb and Equalizer - and its command line exposes no
   way to turn that off. A compressor alone would account for the shape.
2. MAME resamples the chip's 49.7 kHz to 48 kHz.
3. jtopl2's envelope decay genuinely differs from ymfm's.

Ruling out the first needs MAME's mixer UI, which needs a display.

### What the silence before that actually is

Not nothing: `snd` holds a decaying positive DC offset, 2586 falling to exactly
zero by 14 s of board time, each value held about 4096 samples. That is the
envelope generators settling from power-on. After 14 s the core is bit-silent,
and so is MAME.

## The CRTC is an independent check on the video timing

Like every other jtcore, this one will hardcode its raster rather than model
the 6845 - MAME does the same, and its CRTC has no callbacks wired at all. That
leaves the hardcoded numbers unverified, so `crtc_check.py` reads the values
the game itself writes to the chip at boot and derives the raster from them:

```
  htotal    programmed  446   hardcoded  446   match
  hvisible  programmed  320   hardcoded  320   match
  vtotal    programmed  286   hardcoded  286   match
  vvisible  programmed  240   hardcoded  240   match
```

All four figures match the ones taken from MAME's `set_raw()`, derived from a
completely independent source: the hardware's own software.

## Known limitations

- **Audio is now checked, and the core makes sound.** See below.
- **No video output here.** The tile maps, palette and sprite RAM are all
  present and the game demonstrably fills all of them, but nothing renders in
  this bench. `+snap=` hands their contents to `ver/video`, which does render
  them and diffs the result against a MAME-transcribed reference; that is where
  "the game is drawing the right thing" is established.
- **The halt is modelled by removing the CPU's clock enable**, which stops it
  immediately, as MAME's `INPUT_LINE_HALT` does. The real board most likely
  uses BUSRQ, which would let the current instruction finish first.
- **Verilator, not iverilog.** The T80 is 21k lines of generated Verilog and
  iverilog is far too slow to reach the end of the power-on tests.
