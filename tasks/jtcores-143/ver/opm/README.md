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
this does not calibrate the CPU's physical delay loop. Capture intentionally
waits 512 API clocks after the program, then snapshots at a consistent pipeline
cycle. This makes it suitable for steady single-operator PG tests, not envelope
attack alignment. Files are created exclusively to retain previous evidence.

The source-review interface summary is saved separately in
`artifacts/opm-reference/interface.md`; it describes the reference behavior
without reproducing third-party implementation code. Internal increments are
model observations and do not establish the real chip's internal state.
