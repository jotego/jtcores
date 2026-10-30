# Continue through the existing CPU and serial interface

The user's 2026-10-19 clarification supersedes the hardware prerequisites in
`offline-dispositions.md` and the original remaining-controls report. The CPU
already drives /CS,/WR,A0,D0..D7 and produces controlled register/output changes.
The user's 3.57–3.58MHz on-pin measurement remains sufficient. Package-level bus
probes and a second chip are optional diagnostics, not prerequisites for the
remaining output investigation. No new wiring, clock measurement or PCB reboot
is requested.

Use the existing resident monitor and SO/SH1/SH2 capture. A fresh idle/boot-bank/
generation qualification and ten bipolar/pan/whole-zero controls passed in
`/nobackup/tasks/jt51-16/round3-20261019-serial-controls/`. No ROM/FPGA reload or
CPU reset occurred. Existing sealed archives remain unchanged; new captures
and analysis use this separate round and a later archive case.

For pitch, independently inspect saved raw PCM and literal full programs, then
change KC/MUL in one held C2 history with positive/restoration controls. Longer
stride 8 recordings cover several cycles of the slow56-increment observation.
Measure dimensionless native increments using crossings and an independent FFT;
do not infer frequency from host time or change the measured master clock.
Freeze the observer before acquisition and preserve three initializations and
matched quiets. A reproducible physical anomaly can be recorded separately from
a supported shared-JT51 requirement; second-chip availability does not gate the
finite investigation.

For relative phase, retain a continuously running reference on the opposite
output, jointly key the target operators through the CPU, and compare exposed
operators on the same serial timeline. Include key-order, deterministic delay,
reverse exposure, restoration and leak controls. Audit legal public-driver
pulse widths offline if they can change the existing64-residue result. These
measure relative output behavior; exact package acceptance timestamps/internal
reset topology remain unobserved and must not be claimed.

Do not fit away per-operator phase/gain, tune tolerances against the data, or
adopt the old experimental RTL merely to match one reference. Classify the
observations using these controls and explicit limits. Keep Rastan #15 last;
absence of an auxiliary probe alone is not a reason to stop this work.
