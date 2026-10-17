# Diet Go Go YM2151 measurements

Work in progress for [jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143).
The full validation scope and current evidence are in [plans/validation.md](plans/validation.md).
Bring-up and decoder qualification do not yet validate jt51's subsystems.

## Hardware and initial state

PicoROM is **P28_27C512_70ns**, device `E66550A14758A021`, replacing the 64 KiB
`jw_02.14m` sound ROM. Its original volatile image was backed up locally; it was
all FF bytes. Reset is unconnected and remains high impedance. The installed
diagnostic firmware was built from PicoROM commit
`c2fa947d8c1ca8a1e7cb0b9b4b4dcd331aff5fff` in
`/nobackup/jtmisc/reverse/PicoROM`, specifically the P28 target. It reports
`diag_version=jtkcpu-1.6`. POG/P32 builds have different pin assignments.

Chameleon96 USB Linux is at `192.168.96.96`, using the retained SSH configuration
`~/jtcores/tasks/SiliconRE-5/scripts/ssh-config` and alias `chameleon96-usb`.
The capture design assigns J3.16/18/20/22 (FPGA E5/F5/A6/A5) as input-only 1.8 V
pins. These are the same assignments as the previous qualified capture design.
Raw observations identify two staggered strobes on bits 0/1 and SO-like data on
bit 2. The user confirmed that the outputs pass through open-drain inverters
into the 1.8 V domain. Both decoders correct inversion before interpreting edges
or data (mask 15, including the unused fourth input). Absolute left/right names
are qualified by independent pan controls: latch channel 0 is right, channel 1
is left. Tools retain latch-based labels so evidence remains tied to input pins.

The user reports a YM2151 clock of **32.22 MHz / 9 = 3.58 MHz**, confirmed on-pin
at 3.57–3.58 MHz with 0.01 MHz measurement tolerance. Nominal native sample rate
is **55,937.5 Hz**. Raw SH timing independently measures about 55,937 Hz. The
package marking reported by the user is **9223 EAEG**. A user-confirmed PCB power
cycle returned the resident monitor's fresh `B0 2A 00` boot frame; Chameleon96
and PicoROM remained running. [Phase measurements](plans/phase-measurements.md)
record the discrepancy that persisted after that reset.

## Sound CPU monitor

Source root `setprj.sh` before project commands. Build with cc65's `ca65` and
`ld65` on PATH, or provide their paths as `CA65` and `LD65`:

```
bash tasks/jtcores-143/scripts/build-monitor.sh
```

The 8 KiB boot image is repeated through a 64 KiB ROM. After testing all 8 KiB
of sound RAM without using a stack or RAM variables, boot copies the 173-byte
monitor to RAM at logical 2200. Its code no longer depends on the flashable ROM.
Mappings are MPR1=F8 (RAM), MPR2=88 (YM2151), MPR3=01 (control/comms ROM),
MPR4=02 (command table). Interrupts are masked. The host may replace the table
while the CPU idles, verifies its USB readback, then writes a new generation
and its complement. A completed command returns a three-byte frame.

Use Python with PyUSB installed. The workstation already has it in
`~/jtcores/tasks/jtkcpu-1/tools/venv/bin/python`. `pico_link.py` reuses that task's
small USB protocol client. The checked-in sources contain no credentials.

```
python scripts/monitor.py install
python scripts/monitor.py poll --seconds 60 --until-reply
python scripts/monitor.py run timer-a --until-reply
python scripts/monitor.py run clear --until-reply
python scripts/monitor.py run timer-b --until-reply
python scripts/monitor.py run tone --until-reply
python scripts/monitor.py run silence --until-reply
```

Those examples run from this task directory. `install` disables ROM service,
uploads and verifies the whole image, arms communications at physical 3C00,
then enables service. **Use it for initial installation, not for routine tests.**
An arbitrary CPU state might require a PCB power cycle to enter the monitor.
The first physical install happened to return its boot frame without one.
Keep PicoROM USB powered during PCB power cycles so the volatile image survives.

The host records pending commands in `artifacts/monitor-state.json` and rejects
overlapping submissions. After a timeout, use `poll` before issuing another test.
Do not delete the state to bypass a pending operation. A reset during a pending
test is reported as an error. Each PicoROM session has a 4096-marker limit;
current runs use three markers per reply. A session rearm procedure will be
needed before exhausting that budget.

Bytecode, supplied as a binary file with `run --program FILE`:

| Bytes | Operation |
|---|---|
| `00` | Complete and return `D0 generation status` |
| `01 register value` | Wait for YM2151 busy, then write register/value |
| `02 low high` | Delay by a 16-bit CPU loop count; zero means no delay |
| `03` | Read YM2151 status into the completion frame |

Startup returns `B0 generation status`. Unknown opcodes return completion status
FF. Host tables must fit 8 KiB and end in 00; this is a trusted experiment format,
not a sandbox for arbitrary bytecode. CPU delay counts are not calibrated timer
measurements. Timer smoke tests only check overflow/reset flag behavior.

## Capture design

The board/HPS transport, PRNG, raw and PCM modes reuse
`~/SiliconRE/Konami/054539/chameleon96`. This task adds mode 3 for Yamaha.
It measures intervals between alternating SH falling edges and samples sixteen
SO bit cells at their centers. It preserves the full serial word, including
the three unspecified bits. Invalid/missing strobes increment framing errors;
the analyzer rejects captures with any framing error.

Protocol ID is 960103. Existing modes 0/1/2 keep their existing file format;
mode 3 uses `C96CAP03`, an 80-byte little-endian header with the same fields as
`C96CAP02`, version 3 at offset 12, mode 3 at offset 52, and the latest measured
stereo-frame interval in FPGA clocks at offset 68. Offsets 72/76 stay zero.
This interval is integer-quantized and gives approximate absolute sample rate.
Payload words start at latch channel 0 and alternate 0/1. Each 16-bit word has
three unspecified bits at [2:0], an offset-binary mantissa at [12:3] and exponent
at [15:13]. The analyzer reports exponent zero as invalid.

The framing basis is Yamaha's YM2151 terminal description and
[YM3012 data/timing documentation](https://ftpmirror.your.org/pub/misc/bitsavers/components/yamaha/YM3012_199204.pdf),
particularly its serial ordering and SH latch timing. The local source scan is
retained in artifacts. No assumption of standard I2S framing is made.

Build after sourcing root `setprj.sh`, with Quartus 20.1.1 and `dtc` on PATH:

```
bash tasks/jtcores-143/board/build.sh tasks/jtcores-143/artifacts/c96-yamaha-build
```

Use `board/load-fpga.sh` on the board with the compiled RBF/DTBO in
`/lib/firmware` and matching `host/c96-capture.c` compiled as
alongside the loader as `/home/root/jtcores143/c96-capture`. Invoke the loader
with `yamaha`; firmware filenames are `c96-yamaha.rbf` and `c96-yamaha.dtbo`.
The loader quiesces fabric drivers, uses the old
kernel's configfs `path` method, probes the design ID and preserves SD boot files.
Record backups and hashes of replaced runtime files first. The original boot
image and USB recovery remain available. Example board commands:

```
./c96-capture configure 3 15 0
./c96-capture capture /tmp/unique-name.cap 1 32768 1 151
```

Transfer with legacy SCP (`scp -O`), compare HPS and PC SHA256, then analyze:

```
go run host/analyze.go artifacts/unique-name.cap
```

Mode 1 raw recordings can be decoded independently by the same tool. It checks
metadata, strobe order, timing stability and SO bit-center margins. `-csv PREFIX`
exports decoded words for each channel to fresh files.

## Verification

The installed Verilator 5.018 needs the established task wrapper that removes
the unsupported `--quiet` argument:

```
export PATH=$HOME/jtcores/tasks/SiliconRE-5/scripts/verilator-compat:$PATH
simunit.sh --run tasks/jtcores-143/ver/yamaha
simunit.sh --run tasks/jtcores-143/ver/capture
bash tasks/jtcores-143/ver/replay/sim.sh
go test tasks/jtcores-143/host/analyze.go tasks/jtcores-143/host/analyze_test.go
```

Run these from the repository root with its environment sourced. Replay requires
a local raw capture (`high.cap` by default; override with `YAMAHA_REPLAY`). It
compares every full RTL word with the independent offline decoder, including
channel identity and unspecified low bits.

`scripts/check-monitor.lua` runs the assembled image in local MAME `dietgoe`
(the installed MAME 0.260 ROM set matches this clone). It verifies RAM boot,
communications, timer status, live command generations and physical YM2151
register writes. `CHECK_TONE=1` additionally exercises a multi-page tone table.
Always wrap MAME in `timeout 5m`. Retain and inspect its PASS output: MAME's
process status alone does not report Lua assertions. The optional WAV has been
checked non-silent and measured at about 440 Hz.

The [jt51 harness](ver/jt51/README.md) accepts the same binary register programs.
Generate one offline (from this task directory) using
`python scripts/monitor.py emit tone --output artifacts/fresh-tone.bin`, then run
`bash ver/jt51/sim.sh artifacts/fresh-tone.bin artifacts/fresh-jt51.csv`.
It has been checked for a 64-clock native sample cadence and a nonzero 440 Hz
tone matching MAME. Its steady pitch is now compared against post-reset PCB
recordings and an [independent OPM oracle](ver/opm/README.md). Transient capture
alignment remains unqualified.

## Steady phase measurements

Generate the complete 243-case PG matrix from the canonical tone, using a new
output directory. It covers all KC values, all KF values at KC=4A, all DT1 values
at KC=4A, all DT2 values at KC=40 and all MUL values at KC=40. It adds multiplier
interaction sweeps at KC=4A/50/60:

```
python scripts/monitor.py emit tone --output artifacts/fresh-tone.bin
go run host/programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-pg
```

Each generated program contains the full initialization and one controlled
single-operator voice. The manifest includes program hashes. Apply a program
with `monitor.py run --program FILE --until-reply`, capture mode 3, and submit
the identical file to the jt51/OPM harnesses. Transfer hashes and zero framing
errors are prerequisites for accepting a physical capture. Preserve failed
recordings separately; do not include their samples in a result.

The phase fitter regresses inferred sine phase against native sample index.
Its result is independent of master-clock calibration and initial phase:

```
go run host/phase.go host/tone.go -sample-rate 55937.5 artifacts/capture-0-0.csv
go run host/phase.go host/tone.go -column left -sample-rate 55937.5 artifacts/jt51.csv
go test host/phase.go host/tone.go host/phase_test.go host/tone_test.go
```

It requires a controlled, unmodulated single sine of known peak amplitude
(default 8170, quantization offset -8), consecutive samples, and positive
effective phase advance below one eighth of the sample rate. It rejects silent,
non-sinusoidal, changing-frequency and malformed inputs. This estimates an
effective 20-bit phase increment from output; it does not read internal chip
state or establish transient envelope equivalence. `-sample-rate` is optional
and adds a calibrated frequency without altering the fitted increment.

## Timer measurements

[Timer results](plans/timer-measurements.md) record a physical status-flag gap
in production jt51 and the uncertainty of period-boundary observations. The
production revision remains frozen while measurement gaps are collected.

```
go run host/timer_programs.go -output artifacts/fresh-timers
bash ver/timer_flags/sim.sh
```

The standalone timer conformance probe intentionally returns failure against
the frozen baseline; it is not registered in CI. Its README distinguishes
physically measured status behavior from unobserved physical IRQ behavior.

Artifacts, generated fixtures, builds, ROMs, captures and local state stay out of git.
