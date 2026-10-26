# External OPM oracle

This standalone driver accepts the same monitor bytecode as the jt51 harness.
It calls the public Nuked-OPM API and exports native DAC samples with the four
channel-0 operators' internal phase increments and C2 phase. No emulator
implementation is copied or translated into this repository, and the external
checkout is never modified.

```
bash tasks/jtcores-143/ver/opm/sim.sh PROGRAM.bin FRESH.csv [SAMPLES]
go run tasks/jtcores-143/host/phase.go tasks/jtcores-143/host/tone.go -column left FRESH.csv
```

Optional `--stride N`, before the program arguments, retains every Nth native
stereo frame in either steady or event mode. N is from 1 through 1024, default 1:

```
bash tasks/jtcores-143/ver/opm/sim.sh --stride 1024 PROGRAM.bin OUTPUT.csv 16384
bash tasks/jtcores-143/ver/opm/sim.sh --stride 3 --event INIT.bin EVENT.bin OUTPUT.csv 1024
```

The retained native indices are 0, N, 2N, and so on, counted from capture start.
CSV `sample` indices count retained frames consecutively; `SAMPLES` requests that
many retained stereo frames. Actual master-clock timestamps are retained, with
64*N clocks between rows. The external model executes every intervening clock
and the complete EVENT program. The recorded sample rate is 55,937.5/N Hz at
3.58 MHz, without any claim of phase alignment with the PCB or jt51.
The sample-count bound remains 10,000,000, with SAMPLES*N additionally limited
to 16,777,216 native frames. The maximum 16,384-by-1024 case covers about
300 seconds of chip time while writing only 16,384 rows. Stride 1 preserves
previous sample CSVs and event sidecars byte for byte for identical inputs.

`NUKED_OPM_ROOT` defaults to `/nobackup/jtmisc/reverse/Nuked-OPM`. The qualified
checkout is commit `a0ab44be60cb28b68431779829454ddf3284f272`, whose source identifies
itself as version 0.9.2 beta. Nuked-OPM is copyright Nuke.YKT, licensed under
LGPL-2.1-or-later; its implementation and license remain in that external checkout.
Generated executables, logs and comparisons belong in `artifacts/opm-reference`.
The linked local executable incorporates that external LGPL code; it is a local
validation artifact and is not checked into this repository.

The driver resets the model using `OPM_Reset`, submits address/data writes through
`OPM_Write`, and polls status busy using `OPM_Read`. One `OPM_Clock` advances half
the external master-clock rate. Thirty-two calls produce one native frame, or
64 master clocks. At the user-specified 32.22 MHz / 9 input, this is 55,937.5 Hz.
CSV `clock` counts master clocks after the API reset routine. Its absolute origin
is not synchronized to the PCB or jt51 harness.

Delay bytecodes use the same nominal 32 master clocks/count as the jt51 harness;
this does not calibrate the CPU's physical delay loop. Steady capture intentionally
waits 512 API clocks after the program, then snapshots at a consistent pipeline
cycle. This makes it suitable for steady single-operator PG tests, not envelope
attack alignment. Files are created exclusively to retain previous evidence.

The source-review interface summary is saved separately in
`artifacts/opm-reference/interface.md`; it describes the reference behavior
without reproducing third-party implementation code. Internal increments are
model observations and do not establish the real chip's internal state.

Transient event captures use the compatible optional interface:

```
bash tasks/jtcores-143/ver/opm/sim.sh --event INIT.bin EVENT.bin OUTPUT.csv [SAMPLES]
```

INIT executes first, followed by 4096 input master clocks of settling. Capture
starts before EVENT executes, with output recorded throughout its writes, busy
waits and delays, then until the requested native frame count (default 16384).
There is no post-event settling gap. Snapshots occur at the same operator cycle
once every 64 master clocks by default, including during EVENT. If EVENT outlasts the
capture window, it still completes but no rows beyond the requested count are
written. This supports envelope-duration and level measurements; initial state
and event timing are not synchronized exactly with the PCB or jt51.

Event mode also exclusively creates `OUTPUT.csv.events.csv`, with columns
`kind,clock,reg,value`. `capture_start` gives the arming master-clock timestamp.
`write` gives the master-clock timestamp of submitting EVENT's data byte to
`OPM_Write`, with decimal register/value fields. This API submission time is not
the model's later internal register-latch time. INIT writes are not included;
EVENT writes after the capture window still appear. Timestamps count input
master clocks after API reset, including setup, settling and bytecode execution.
The external-model and jt51 clock origins differ. Delay opcodes remain
approximately 32 master clocks/count and do not reproduce CPU instruction timing.

Optional `--keyon-phase P`, before `--stride`, delays nonzero register08 data
API calls to even master-clock residue P modulo64. Only0,2,..62 are accepted:
the original two-master-clock API cadence is preserved. It implies
`--public-bus`; that flag alone logs without inserting timing. Both exclusively
create `OUTPUT.csv.bus.csv`, retaining INIT/EVENT address/data API calls and
status. No internal register-acceptance timestamp is inferred. Default runs
create the original files with original timing. The
[algorithm phase methods](../../plans/algorithm-measurements.md) retain the
32-presentation coverage and physical phase uncertainty.
