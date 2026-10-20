# DataStorm TEI0022 regression runner

Work for [jtcores #145](http://gitea.jotego.es/jotego/jtcores/issues/145).

## Version 4 and scalar interrupt entry

This checkout's RTL, transport and receipt writer now use protocol 4. The
V3 physical checkpoints below retain their original source/image identities;
use the corresponding V3 checkout and driver to reproduce them. Physical V4
source `d668c39968cc946dac20883f32f573bd1112a9c6` has been fitted and programmed;
its scalar IRQ timing failures below remain the baseline for this CPU change.

V4 stages up to 16 events per case before CPU release. The sequencer drives
the normal LINT1/2, HOLD, EMU, CEN and HSTCTL interfaces from deterministic
clock, write, decode, delay or acknowledgement triggers. Applied events,
HOLD edges and host ACKs share the bounded diagnostic contract described in
[PROTOCOL.md](PROTOCOL.md#version-4-external-events). Both runner components
are bound into programming receipts; old receipts fail before board access.
Programs, event tables and Python expectations remain runtime data.

Local checks retain the existing independent ISA oracle. They do not treat
an observed event count or pause as expected instruction timing.
`event_cases.py` layers event conditions on unchanged ISA fixtures. The first
`early_cen` contract declares a fixed 1/7/8-clock pause and requires the exact
two-entry clock schedule; its declared delay feeds the existing timing oracle.
Architecture, status, memory, bus order and instruction counts remain checked.
Unknown event contracts and overlap with the legacy pause setting fail closed.

`check_external_reference.py` compares the Avalon runner with the original
full-system bench using `reference_stimulus.sv`, a separate behavioral scheduler
that drives real LINT/HOLD/EMU/CEN/HSTCTL ports. It does not instantiate the
synthesizable sequencer or its packed event RAM. The default original bench
is unchanged unless compiled with `JTTMS10_EXTERNAL_REFERENCE`. The local
38 ordinary event cases cover all six trigger types, all 16 table entries, HOLD ACK,
host NMIM writes, and early CEN with zero/one waits on arithmetic, unaligned
loads and regular PIXBLT. Both backends compare application clocks, counters,
HOLD edges, host ACKs and every existing architectural/timing/bus observation.
This reference is limited to 64 short cases; long supported matrices use FPGA.

Twelve additional `irq_scalar_*` cases drive real LINT1/LINT2 through the I/O
fabric, with W0/W1/W3 memory waits. They keep a measured one-state NOP and use
a following ADDK counter to check continuation across an ISR/RETI. Independent
checks cover initialized registers/ST/SP, the saved frame and vector, MSW-first
entry writes, ordered vector/handler/RETI reads, and every raw/logical transfer
duration. The complete post-measurement trace is retained and compared between
backends. The existing ISA oracle and its fixture definitions are unchanged.

Six IRQ cases prefill the actual handler by executing it before measurement.
With an aligned stack, no refresh/host traffic, a warm handler and one-state
ADDKs, SPVU001A 8.5.1/Table8-4 requires recognition1..2 plus context16 states.
Six entry-word waits add six wait states per configured wait. The checker
allows one INCLK for the recorded falling/rising edge difference. The baseline
CPU in `d668c3996` **fails** all six warm-entry bounds: W0 observes183
versus135..145 INCLK; W1 observes231 versus183..193; W3 observes327
versus279..289. Physical V4 and both Verilator backends agree on all50
observations:44 pass and six fail solely on entry timing. These failures remain
requirements. See
[interrupt notes](../../docs/interrupts.md#external-pin-entry-timing-baseline).

The timed CPU now submits complete 32-bit PC/ST fields to the existing adapter,
which preserves MSW-first writes and avoids extra halfword bus slots. The raw
CPU retains its original helper sequence. Both short Verilator backends pass
all50 cases with warm pin-entry latencies143/191/287 INCLK. An additional exact
check uses the architecturally verified ADDK counter and saved return PC to
identify the acceptance boundary: context must be exactly16 states plus the
six configured word waits (128/176/272 INCLK). It does not infer a golden count
from the implementation. This CPU change still requires fitting, STA and FPGA
validation; the loaded physical baseline does not contain it.

`check_irq_mutations.py` rejects actual CPU changes that restore the slow entry,
reverse the frame word order, or skip an instruction on return. Ordinary NOP
controls must pass and timeout/compiler failures do not count as detections.
The slow-entry mutation preserves final architecture and memory but fails the
exact context count. The order mutation preserves final values but fails the
bus plan. Run it with `--output /path/to/new-irq-mutation-evidence` to retain
raw captures and the altered source. It also runs from `ver/run.sh`.

To prepare the same50 runtime cases for an already validated FPGA image without
building a simulator, use `check_external_reference.py --prepare-only --output
/path/to/new-directory`. Its `manifest.json` is an ordinary input to
`run_batch.py`; fixture/expectation changes do not recompile the FPGA.

`check_event_mutations.py` changes actual sequencer RTL. Early CEN release
returns correct registers/status but 14 clocks instead of the declared 15;
wrong HSTCTL data injects an unintended NMI. Both fail with unaffected controls.
Graphics IRQ/NMI continuation and outstanding-work HOLD/EMU/CEN contracts remain
pending. The scalar entry baseline does not establish those contracts or full
instruction timing compliance.

### Physical V4 baseline and build measurements

RBF SHA-256: `a354a9db3777812d435e234bf68dac048439a7b185c6c201df8bb2391dd7ad00`;
overlay `jtcores-144-v4-a354a9db`; SYSID22/1792433033. Hardware source is
`d668c3996`, with independent host fixtures from clean `48dba0aae`. The50
external cases take4.508 s enclosing driver wall, with all raw observations
matching Verilator, including the six identified timing failures. Programming
takes0.324 s on the target,1.463 s enclosing SSH. Evidence is under
`/nobackup/tasks/jtcores-144/artifacts/v4-events-baseline-1/` and
`artifacts/fpga-stimulus/v4-program-1/`.

On that same image, the ordinary base matrix passes all141,972 cases /133 forms
in5190 batches without exclusions; every raw verdict independently replays.
Enclosing driver wall is293.539 s, including transfer10.865 s and Python
checking54.684 s. Target staging/run/draining total11.749/53.067/113.891 s
and nest within the remote-execution phase. Preparation was observed at about
62.8 s from tool wait intervals, without an exact enclosing monotonic timer.
Short candidate debugging jobs overlapped this development measurement, so it
is not a matched software speedup benchmark. Full evidence and source/receipt
bindings are in `artifacts/v4-full-base-1/`. This ordinary matrix does not waive
the six separate warm IRQ failures or validate the new CPU entry schedule.

The V4 build uses `/opt/quartus_free/quartus_sh --flow recompile test_board`
with preserved parent IP/database. The actual command takes1153.940 s
(1159.694 s enclosing helper). All88 reported STA rows have positive slack
and zero TNS; all32 calibrated DDR rows match the positive parent. The appliance
fits9342 ALMs,370 M10Ks and five DSPs, retaining inferred CPU/runner RAMs.
Quartus reports that the main partition change is too large for Rapid Recompile
and performs full compilation there: only0.88% placement and0% routing survive.
This demonstrates use of the flow, not an incremental speedup or final NARC
area/timing acceptance. Preserve this limitation in comparisons; stable HPS
and CPU partition reuse still needs improvement.

From a checkout with `setprj.sh` sourced, run the host preflight/capture checks
and short Avalon recovery tests with:

```sh
python3 -m unittest discover -s modules/jttms10/ver/fpga -p 'test_*.py'
python3 modules/jttms10/ver/fpga/check_external_recovery.py \
    --output /path/to/new-v4-recovery-evidence
python3 modules/jttms10/ver/fpga/check_external_reference.py \
    --output /path/to/new-v4-reference-evidence
python3 modules/jttms10/ver/fpga/check_event_mutations.py \
    --output /path/to/new-v4-event-mutation-evidence
```

The recovery suite deliberately supplies malformed tables directly to Avalon,
then checks unapplied/late events, host protocol violations, CEN/HOLD timeouts
and trace overflow. Every failure must preserve the next independently checked
case and a clean rearmed batch. It uses no board access. These checks also
run through the module's standard `ver/run.sh`.

## Latest version 3 image: binary IRQ source checkpoint

The physical image built from clean CPU source
`a06dbcf0d4ff5a718714cc02a29b85eb823d71ab` passes all **141,972 fixtures /
133 forms / 5,190 batches** each base, W1/P7-after0 and W3: **425,916 FPGA
executions**, no exclusions. Every raw verdict independently replays and
reproduces its saved report. All 162 focused observations match original
Verilator. Each full profile includes 184 binary and 360 regular PIXBLT cases.
The V3 runner cannot inject IRQ/HOLD: these ordinary executions do not prove
the new native IRQ continuation on physical hardware.

| Profile | Enclosing host wall (s) | Transfer (s) | FPGA staging (s) | FPGA run (s) | FPGA draining (s) | Python checking (s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Base | 286.074 | 10.879 | 11.633 | 53.034 | 113.395 | 53.163 |
| W1/P7-after0 | 292.146 | 10.837 | 11.805 | 59.289 | 116.030 | 52.014 |
| W3 | 304.370 | 10.601 | 11.845 | 70.327 | 116.109 | 52.093 |

Full walls include transfer, execution, checking and serialization. Target
phases nest within transport execution; do not add them twice. No heavy local
job overlapped the measured full commands. Manifest preparation took 765.296 s
including a recorded NFS stall. There is no matched full software benchmark.
Timeout and explicit 512-record overflow return failure while the next case
and clean rearm independently pass. All 164 published MOVB diagnostics match
Verilator, retaining 27 CD duration failures (137 passes). No target is waived.

RBF SHA-256:
`7f69384643a0f89cbbfece714b9137fd4699fbd9dc2faa33804f780e57b14ce4`.
Overlay/firmware: `jtcores-144-binary-irq-7f693846`; protocol 3; SYSID22 /
1792433033. Original clean-source receipt SHA-256:
`effe2fd9aa251e2af5d2802a81f5b142fbb29434bd645f41a9d31bf8147e3f39`.
Evidence: `/nobackup/tasks/jtcores-144/artifacts/binary-irq/`.

`/opt/quartus_free/quartus_sh --flow recompile test_board` reuses the fitted
parent's generated IP/database. Its enclosing wall is 3913.170 s; Quartus
reports 3620 s. Terminal preservation is 73.99% placement and 26.30% routing.
This is slower than the preceding different-source 864.03 s Rapid run; no
general speedup is inferred. All 88 final STA rows are positive with TNS0;
minimum setup/hold is +0.583/+0.077 ns. All 32 calibrated DDR rows remain
positive and identical to the parent; SDC is unchanged. Eight runner RAMs,
two RF mirrors, four cache banks and the 4096x64 graphics ROM remain RAM.
The appliance fits 9,108 ALMs, 6,850 registers, 351 M10Ks and five DSPs.

Corrected programming takes 0.327804 s on target /2.237301 s full SSH with
payloads staged. An initial attempt loaded the same image under a stale
overlay tag and failed its final identity assertion before tests. Its
0.324884 s programming time and failure are retained separately. The script
destination was corrected, and the same RBF was safely reloaded under the
unique tag before the successful receipt and tests. Final health shows the
unchanged boot identity, operating manager, enabled bridges and kernel taint0.
This checkpoint does not establish full timing compliance, CPU-only area,
clean/CI or NARC/MiSTer acceptance.

## Historical version 3 validation: native binary PIXBLT

RTL commit `2a5e4a6d95909c758d3041e0603fc6a8276fed60` adds aligned opaque B,L / B,XY
expansion through the shared datapath for DX<=32, all five pixel sizes,
complete destination words and aligned rows/pitches. All **141,952 fixtures /
133 forms / 5,188 batches** pass each base, W1/P7-after0 and W3 on one
configuration: **425,856 FPGA executions**, with **no fixture exclusions**.
Each profile includes all 164 binary and 360 regular PIXBLT fixtures.
Every raw verdict is independently replayed and reproduces the saved report.
All 102 focused physical observations match original Verilator for architectural
state, memory, instruction clocks and checked bus/target events.

| Profile | Enclosing host wall (s) | Driver wall (s) | Transfer (s) | FPGA staging (s) | FPGA run (s) | FPGA draining (s) | Python checking (s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Base | 305.330 | 291.986 | 12.023 | 11.981 | 53.009 | 115.800 | 52.615 |
| W1/P7-after0 | 311.540 | 298.242 | 12.019 | 11.984 | 59.263 | 115.813 | 52.739 |
| W3 | 323.210 | 309.646 | 12.221 | 11.883 | 70.341 | 115.421 | 52.776 |

These measured command walls include transfer, execution, checking and final
serialization. The enclosing wrapper also hashes manifests/captures and records
evidence; its larger wall is distinct from the driver invocation. Target
staging/run/draining nest within SSH execution; do not
add them twice. Preparation of all twelve reusable manifests took 372.673 s.
The full matrix has no matched software benchmark; no new speedup ratio is
claimed. The historical FILL pair below belongs to its stated older image.

Timeout and explicit 512-record overflow fail the host command and preserve
the next independent case and clean rearm. The separate 164-case published
MOVB command retains 137 passes / 27 CD duration failures; all diagnostic
observations and error lists match original Verilator. These failures remain
requirements. Short local Verilator runs reject functional/timing binary RTL mutants with unchanged Python
expectations and passing NOP controls. Seventy architectural boundary vectors
pass normally and with actual HOLD locally; this is not FPGA HOLD scheduling.

RBF SHA-256: `dab7a6fcee1cf0634d38b725aa5224ccd0d027c26a3ca526e0b613a227877518`.
Overlay/firmware: `jtcores-144-binary-dab7a6fc`; protocol 3; QIP-bound SYSID 22 /1792433033.
CPU fingerprint: `3916d604af42d0cc34638eb801e32485c46f9c21e81be5b025e36ea3a142d982`.
Original clean-source receipt SHA-256:
`1d38776a4ed7b5236fe308d6290ceb6a73da654b9a8957755840cce2bc723639`.
Evidence and original receipt: `/nobackup/tasks/jtcores-144/artifacts/binary-native/`.
Use image, source, receipt, overlay and boot identity together; inherited SYSID
alone does not distinguish the image. Later documentation/tool commits do not
relabel this fitted source.

Both build attempts preserve the fitted regular parent's generated IP/database
and use `/opt/quartus_free`. The full flow exits 0 in 912.02 s (916.67 s outer),
but its HPS lightweight-AXI-to-LED setup path has -0.106 ns slack; its image is
rejected. A separate source-identical changed-RTL Rapid Recompile takes 864.03 s
and runs map/CDB/fit/assembly/STA. Its explicit certificate binds parent,
frozen inputs, fresh reports and image; it is the programmed result. All 88
final timing rows are positive with zero TNS: setup min +0.895 ns, hold +0.077 ns,
runner setup at least +3.491 ns. All 32 calibrated DDR rows are positive and
identical to the parent; SDC is unchanged. The rejected full attempt is not a
timing-closed comparison baseline or proof of a general compilation speedup.

The Rapid appliance fits 8,458 ALMs, 7,107 registers, 351 M10Ks, 2,805,760 RAM bits,
five DSPs, one PLL and one DLL. Eight runner RAMs, two RF mirrors, four 32x16 cache banks
and the 4096x64 graphics ROM retain inferred RAM. Whole-appliance fit/STA is
separate from CPU <=3500 ALMs and NARC/MiSTer acceptance. RBF transfer took 1.320 s
(all programming payloads 4.919 s); programming took 0.329264 s on target and
1.394727 s for SSH with the image staged (1.50 s outer).

Long supported matrices run on DataStorm; short Verilator runs debug changes.
Native binary IRQ/NMI checkpoints/context now pass local timed-word Verilator
checks described in [PIXBLT timing](../../docs/blit-timing.md). The loaded image
above predates those edits. Twenty additional wide-row fixtures also pass local
timing checks; their new image and physical regression remain pending.
FPGA HOLD/IRQ schedules, broader
conditions, remaining MOVB targets, clean/CI and final game validation remain
open. Probe presence and this passing matrix do not establish full #144
instruction timing compliance.

## Historical version 3 validation: native regular PIXBLT

RTL commit `cb113446bbf53a4045564cf3b2a070d008502624` implements aligned opaque
regular L,L / L,XY / XY,L / XY,XY words through the shared CPU datapath. All
360 regular fixtures pass each base, W1/P7-after0 and W3. Eighty-four focused
observations match original Verilator for defined architecture, final memory,
instruction clocks and checked bus/target events.

All **141,788 cases / 131 forms / 5,179 batches** pass each profile on one
configuration: **425,364 FPGA executions**. Every raw verdict was independently
replayed and reproduced exactly. Full passing manifests explicitly exclude the
144 binary fixtures; the separate binary command returns all 144 failing
individual verdicts, with correct architecture/final memory and no overflow.
All fixture expectations remain independent and unchanged. Probe presence for
133 forms and a passing subset do not establish instruction timing compliance.

| Profile | Full host wall (s) | Transfer (s) | FPGA staging (s) | FPGA run (s) | FPGA draining (s) | Python checking (s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Base | 291.21 | 12.513 | 11.738 | 53.040 | 115.268 | 52.499 |
| W1/P7-after0 | 298.16 | 12.693 | 11.620 | 59.197 | 114.435 | 53.116 |
| W3 | 316.90 | 11.986 | 11.634 | 70.220 | 114.105 | 52.607 |

Commands ran sequentially without another transport or heavy local job. Target
phases nest inside SSH execution; do not add them again. They are aggregate
transport/controller phases, not CPU-only runtime. The external wall includes
final serialization and cleanup. These are not matched software benchmarks.
Timeout and explicit 512-record overflow fail the host command; the identified
following case and clean rearm pass independently.

The directed 164-case MOVB command retains 137 passes / 27 CD duration failures,
with unchanged diagnostic observations/errors against original Verilator.
Binary fixtures retain duration and bus/cadence failures. Two B,XY PS2 probes
gain eight clocks versus the historical baseline; current-source short Verilator
reproduces those changes exactly. See [PIXBLT timing](../../docs/blit-timing.md).
No failing capture is relabeled as passing equivalence.

RBF SHA-256:
`0ba7365706fc12699305a09f545f8b18db681aeccbbda5641947b706770a30dd`.
Overlay/firmware: `jtcores-144-blit-0ba73657`; QIP-bound SYSID:22 /1792433033.
CPU source fingerprint:
`1a4be476daf940f32bf41f01e746c21e433ccd654cdab4b2c79b0eb4864036b0`.
Use the source-bound receipt under
`/nobackup/tasks/jtcores-144/artifacts/blit-native/program/` with the image hash,
boot identity and fingerprint; the inherited SYSID alone is insufficient.

Build `/tmp/jtcores-144-blit-native-runner-1` reuses generated IP and databases
from the fitted MOVB parent. A full `/opt/quartus_free` flow takes 848.51 seconds
(853.43 s outer), with 35 source and 171 packaged inputs unchanged. The whole
appliance uses 7,635 ALMs, 7,071 registers, 351/397 M10Ks, five DSPs, one PLL and
one DLL. All eight runner RAMs, both RF mirrors and four 32x16 cache banks
remain inferred RAM; the graphics ROM is now 4096x64. All 88 final STA rows
are positive, TNS0; minimum setup/hold is +1.074/+0.077 ns, runner setup at least
+4.711 ns. The 32 final calibrated DDR rows remain positive and identical to
the parent; 17 negative vendor panels explicitly precede calibration or common
clock pessimism correction. No SDC changed. External HPS I/O warnings remain;
this is not CPU-only area or final NARC/MiSTer acceptance.

Programming takes 0.331 s on target /1.369125 s full SSH with the image staged.
The new receipt preserves its clean fitted source commit; later documentation
commits supplement it without rewriting its identity. This changed-RTL full
flow is not evidence of a Rapid Recompile speedup. Long supported matrices run
on FPGA; short Verilator runs debug changed paths. Native HOLD/IRQ, broader
conditions, clean/CI, remaining timing targets and final game validation stay open.

## Historical PIXBLT failing baseline

Checkpoint `034bd0646` added 464 independent PIXBLT fixtures without changing CPU
RTL, runner protocol or the then-loaded cached-MOVB image. All 84 focused diagnostic
observations across base/W1-P7/W3 agree with original Verilator, including
memory and exact failure lists. Commands fail; these are not passing equivalence
results. The full new base run reports 311 individual timing failures and rejects
153 cases in nine overflow batches; 40 raw cases explicitly reach 512 records.
See [PIXBLT timing](../../docs/blit-timing.md). The preceding 141,428 fixture
contracts and their validated physical results below remain unchanged.

## Historical version 3 validation: cached absolute MOVB

The cached one-word absolute byte path consumes resident operands with the
opcode: 8 INCLK instead of 24; a cold extension uses 80 instead of 96.
The independent TI target and all architectural/memory/bus checks stay active.
There are 192 new A/B/SP, subsegment/segment and byte-boundary fixtures.

All **141,428 cases / 127 forms / 5,157 batches** pass each of base,
W1/P7-after0 and W3 on one configuration: **424,284 FPGA executions**.
Every raw result was independently replayed through the shared Python checker,
reproducing the saved reports exactly. IDs and names are unique; each profile
has 2,060 following-state captures and 1,717,104 event records, with at most
231 of 512 records per case. Transport and checking commands exit 0.
These are the preceding fixture contracts, not complete instruction timing
compliance. The new PIXBLT fixtures above fail, and 401 unresolved MOVB probes,
including 27 agreed CD targets, remain open.

| Profile | Full host wall (s) | Transfer (s) | FPGA staging (s) | FPGA run (s) | FPGA draining (s) | Python checking (s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Base | 286.508 | 10.872 | 11.820 | 52.764 | 114.701 | 52.002 |
| W1/P7-after0 | 289.787 | 10.031 | 11.807 | 58.927 | 114.198 | 52.358 |
| W3 | 301.359 | 11.311 | 11.702 | 70.029 | 113.478 | 51.942 |

The commands ran sequentially with no other board transport or heavy local job.
Target phases nest inside SSH time; full external wall includes serialization
and cleanup omitted by the driver's internal timer. These are observed command
walls, not a matched full-matrix software comparison or stimulus-cost study.

Twenty-three focused cases per profile (69 total) match the original Verilator
bench in architecture, instruction clocks, memory and checked bus events.
The separate 164-case published-target command exits 1: 137 pass and 27 CD
cases fail solely on duration. Absolute CD observes 120 against 56 INCLK;
indirect byte-copy CD observes 72 against 56. All 164 diagnostic observations
and error lists match Verilator. Standard equivalence intentionally refuses
failing captures; this diagnostic match does not waive their timing failures.
Timeout and explicit 512-record overflow commands exit 1, while the subsequent
independent case and clean rearm pass. Three short cached-MOVB timing mutations
also fail with correct architectural results and memory.

RBF SHA-256:
`65d2c2f15e18009f46e2a512af976419de2ff411e11954e330e718cf06881ee5`.
The runner remains protocol 3, SHA-256
`fe9b22038a06ec17610d9763052605538f1a8733cd1c65d5a6d3a3d8624e7ee7`.
Overlay/firmware is `jtcores-144-movb-65d2c2f1`; the actual QIP-bound SYSID is
22 / 1792433033. Use these together with the source-bound programming receipt,
boot identity and CPU fingerprint; SYSID alone is inherited and insufficient.
Evidence is under `/nobackup/tasks/jtcores-144/artifacts/movb-packet-program/`.
Preserve the receipt's original precommit HEAD and dirty-file hashes; a later
commit-content audit supplements that receipt without relabeling it.

The retained-IP `/opt/quartus_free` full flow takes 853.19 seconds
(859.14 s outer helper), exit 0, with 35 source and 171 packaged inputs stable.
The appliance fits in 7,584 ALMs, 7,077 registers, 351/397 M10Ks, five DSPs,
one PLL and one DLL. Four separate 32-by-16 cache banks infer `altsyncram`,
as do eight runner RAMs and both CPU register mirrors. All 88 timing-summary
rows across four corners are positive with zero TNS; minimum setup/hold is
+0.678/+0.077 ns and runner setup is at least +5.843 ns. All 32 final calibrated
DDR margins are positive and unchanged from the parent image. The 17 negative
DDR diagnostic panels explicitly precede vendor calibration or extra common
clock pessimism removal; they are not final margins. No constraints changed.
Vendor unconstrained HPS I/O warnings remain. This appliance fit does not
establish CPU-only area or final NARC/MiSTer timing closure.

The matched 2,240-case FILL subset agrees exactly with the original Verilator
bench. Verilator's ordinary full command takes 26.993 seconds; FPGA manifest
preparation takes 8.344 seconds and the copied skill driver takes 8.531
seconds, or 16.876 combined. This one loaded-image pair is 1.60 times
faster including preparation. FPGA transfer/staging/run/draining/checking are
1.876/0.265/0.914/1.534/0.989 seconds; target phases nest inside SSH time.
Initial compilation/programming are separate upfront costs. No full-matrix,
fresh-image or changed-RTL speedup is inferred. Exact commands and observations
are in `artifacts/movb-packet-fill-benchmark/` under the #144 task.

Programming took 0.335451 seconds on the target, 1.291464 seconds for the full
SSH command, with the RBF already staged. Retain this upfront cost separately
from batch execution. The first wide partial-write cache candidate failed RAM
inference and was cancelled after 880.75 seconds, exit 130; it is not a
successful fit. A fixed-slice probe also failed inference before the four-bank
implementation passed. These development costs and the successful full flow
are not a demonstrated changed-RTL Rapid Recompile speedup.

## Historical version 3 validation: native-LINE checkpoint

The current RTL and SSH transport use protocol version 3. It adds external
stores, independently frozen primary/following register observations, WVP and
the original bench's positive and posted-write drain boundaries. Synchronous
RAMs and FPGA-side target timing remain in use. The fixture definitions and
Python expectations are unchanged. HOLD, external interrupt scheduling and
EMU RUN-low scheduling still require separate extensions.

Version 3 has matched the original Verilator bench for 29 physical observations,
including unaligned/high-address stores, dependent following instructions,
register-list stores, FILL and LINE: 17 base cases and six each at W1/P7-after0
and W3. A separate intentionally failing diagnostic matches the original
memory snapshot and errors when its final boundary coincides with a write ACK.
Physical timeout, 512-record overflow and malformed-descriptor probes fail,
while subsequent independent cases and clean rearm pass.
An additional timeout interrupts an active write during the posted drain;
the next register-list/following case reinitializes overlapping memory and
passes, as does a clean rearmed batch.

That checkpoint's complete matrix passes all 141,236 fixtures across 127 forms in each of
base, W1/P7-after0 and W3: 423,708 FPGA executions on one configuration.
All 5,151 batches per profile pass. Every raw result was replayed with the
original Python oracle; the largest case needs 231 of 512 event records.
Full external host wall is 284.86/296.71/299.87 seconds respectively, exit 0,
including transfer, execution, checking and report generation. These are
observed runs, not a controlled comparison of the profile time differences.
This validates current fixture contracts: six PIXBLT forms have no timing
probes and 448 MOVB source/target cases remain unresolved. It is not full
#144 acceptance.

The image SHA-256 is
`0cdfad2e3f943514cf7d0196962dc915d6363e8f7284f27777fb1b8ba258e9a8`;
runner RTL SHA-256 is
`fe9b22038a06ec17610d9763052605538f1a8733cd1c65d5a6d3a3d8624e7ee7`.
The retained-IP Quartus flow took 820.91 seconds (823.82 s outer helper),
with all 35 source and 171 packaged inputs unchanged. All eight runner RAMs
and both CPU RF mirrors infer `altsyncram`. The appliance fits in 7,284 ALMs
and 348/397 RAM blocks. All four analyzed timing corners have positive slack
and zero negative TNS; runner setup is at least +5.019 ns. This includes the
test infrastructure and is not CPU-only area or final NARC/MiSTer board closure.

| Profile | Full host wall (s) | Batch transfer (s) | FPGA staging (s) | FPGA run (s) | FPGA result drain (s) | Python checking (s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Base | 284.86 | 10.487 | 11.684 | 52.732 | 113.274 | 51.954 |
| W1/P7-after0 | 296.71 | 13.196 | 11.747 | 58.907 | 113.398 | 52.252 |
| W3 | 299.87 | 10.913 | 11.706 | 69.908 | 111.930 | 51.803 |

The target phases nest inside the SSH execution time; do not add them twice.
Full wall includes final serialization/stdout/cleanup omitted from the driver's
internal timer. A short local verification briefly overlapped the start of W3;
these wall measurements do not isolate the cost of each stimulus setting.

The complete 2,240-case base FILL subset also matches the original Verilator
bench exactly through the copied DataStorm skill driver. Its FPGA command
took 9.39 seconds; preparing its manifest took another 8.187 seconds. The
ordinary Verilator command took 26.571 seconds including generation, model
compilation, simulation, checking and reporting. Thus the observed loaded-image
workflow was 17.577 versus 26.571 seconds, about 1.51 times faster including
manifest preparation. This is one matched pair, not a full-matrix software
comparison. The initial FPGA build above and 1.16-second programming SSH command
(0.340538 seconds on the target, image already staged) are separate upfront
costs. It does not establish a fresh-image or changed-RTL iteration speedup.

Preparation and RTL smoke checks default to version 3. The source checker
retains archived V1/V2 captures; the current transport rejects older wire
layouts. Pin the protocol explicitly in reproduction commands:

```sh
python3 modules/jttms10/ver/fpga/check_results.py prepare \
    --protocol-version 3 --matrix --output /path/to/v3-manifest.json
```

The native-LINE image above predates the cached absolute-byte CPU change;
the current image is documented below. Do not bind an older image to changed
CPU source.

To check the 164 agreeing TI MOVB duration targets, use
`prepare --protocol-version 3 --published-targets --output /path/to/targets.json`
instead. These fixtures deliberately select the printed duration while
preserving programs and every other check. Passing targets remain selected;
the remaining CD gaps produce a nonzero host command. The published failing
native-LINE baseline selected 45 then-differing targets. See
[source-policy.md](../../docs/source-policy.md).
The ordinary passing fixture matrix does not establish those targets.

The driver supports up to 8,192 batches, streams returned captures to host
storage and preserves partial
output if its configurable transport timeout expires. Consult the version 3
section of [PROTOCOL.md](PROTOCOL.md) for the exact descriptor/result contract.

## Physical version 2 checkpoint (2026-10-19)

The v2 autonomous runner has executed 154,626 cases on the physical TEI0022:
51,542 supported read-only fixtures each at base timing, W1/P7-after0, and W3.
All 1665 batches per profile passed. Independent raw-capture verification found
no mismatches; the largest individual trace used 141 of 512 records. Full host
command times were 86.28 s, 98.26 s, and 100.75 s, including staging, return
transfer, oracle checking, and report generation. These measurements do not
establish a matched software speedup.

The physical image uses the dedicated no-video test-appliance build: HPS Linux,
Ethernet, and SYSID remain enabled; unused HDMI/DMA logic is removed; the CPU
runner uses a generated 25 MHz PLL output behind Platform Designer's HPS-to-runner
clock crossing, while HPS user1 remains at 100 MHz. The image SHA-256 is
`5c7e6b9a8fc11a6164c12800eaf61eaf31383ad9adc50e88d8b577712c156f2e`; the runner
RTL SHA-256 is
`0a681b94a6b6b0aaa71437975d398508f1294de2f6dbc97ab1ae940e58c709fc`. The
whole appliance uses 6,837 ALMs, 343 of 397 memory blocks, six DSP blocks and
one PLL. All four analyzed timing corners have zero negative TNS; the minimum
setup slack is +1.352 ns on HPS and the runner's worst setup slack is +5.857 ns.
The full Quartus flow took 771.34 s. The programmed SYSID is 22 with timestamp
1792433033, matching the QIP-bound compiled source.

Twenty-one representative fixture executions matched the original timing bench,
including sparse-memory loads, high branch targets, self-jumps, maximum-length
register lists, wraparound stack reads, pixel reads and W1/P7-after0 timing.
Timeout and 512-record trace-overflow negatives returned failure, preserved
their diagnostics, then passed a later independent case and a clean batch
without FPGA reset. A 25,000,000-cycle timeout took 1001 ms on the board's
monotonic clock, consistent with 25 MHz. A separate after7 early-pause negative
records an outstanding request during CEN pause and fails as required by the
original bench; after7 is not an in-flight-response pause mode.

The supported inventory contains 51,542 cases across 93 forms. V2 supports
read-only sparse initialized memory, local memory loads, register-list loads,
pixel reads, control flow, configured target waits, and early CEN pauses.
External writes, following-instruction checks, positive and -2 drain modes,
HOLD, interrupts and EMU RUN-low scheduling remain unsupported and are rejected.
The host checker fails closed on unknown fixture fields. See
[PROTOCOL.md](PROTOCOL.md) for exact fixture boundaries, wire format, commands,
negative tests and immutable evidence paths.

For a changed runner/CPU image, reuse a successful fitted build and its generated
Platform Designer system. The permanent helper supports Rapid Recompile:

```sh
bash modules/jttms10/ver/fpga/build-runner-incremental.sh \
    /path/to/preserved-positive-build \
    /nobackup/tasks/jtcores-144/runner-rapid rapid
```

`rapid` requires a new destination outside the parent directory, a retained
Quartus database, a successful full/Rapid build certificate, unchanged parent
compile inputs, the certified parent RBF and positive final STA with zero TNS.
It clones the parent, updates CPU/runner sources and generated payload without
regenerating Platform Designer, freezes source/build inputs and deletes the
inherited RBF. It invokes exactly
`/opt/quartus_free/quartus_sh --flow recompile test_board` and records monotonic
command wall time and its actual exit code. Preparation time is additional;
measure the enclosing helper command when comparing end-to-end build costs.

The result binds the immutable parent image/input/result/STA hashes and the
new map, fit, assembly and STA reports. Reports, final STA and the RBF must be
newer than the pre-flow snapshot; inputs must remain unchanged, final STA must
be positive and the real Rapid success marker must be present. A failed flow
leaves diagnostics without a successful result certificate. The receipt writer
accepts this explicit `recompile` certificate; it is never labeled a full build.
An unchanged-source run that skips stages does not satisfy these fresh-report
requirements. This flow uses Rapid's preservation; explicit CPU/infrastructure
partitions and a general speedup remain unproven. The source-changing checkpoint
above records the measured preservation and cost.

`python3 -B modules/jttms10/ver/fpga/test_incremental_build.py` exercises parent
binding, cloning, stale-product rejection, changed inputs, failed/wrong commands
and negative STA with synthetic files, without invoking Quartus. These checks
also run through `ver/run.sh`; they are not hardware or compile evidence.

Use `full` for a complete Quartus flow (no mandatory separate map pass):

```sh
bash modules/jttms10/ver/fpga/build-runner-incremental.sh \
    /path/to/preserved-v2-build \
    /nobackup/tasks/jtcores-145/rebuild-v2 full
```

The helper clones the build database and generated Platform Designer system,
regenerates CPU payload files from the source generators, freezes the recursive
QIP synthesis subtree and other compile inputs, removes any cloned RBF, and
runs `/opt/quartus_free/quartus_sh --flow compile`. It retains logs, timing,
source/input hashes, map/flow certificates, and STA reports. The physical v2-7
image was built from its preserved base in a single full flow. Its original
input snapshot omitted the QIP child files; a separate post-compilation audit
verified all 97 synthesis-subtree files unchanged from the base. The recursive
freeze is a later helper correction; it does not rewrite that build's original
certificate. The earlier v1
image and reports are historical and have narrower coverage; the currently
validated image and evidence are recorded in `PROTOCOL.md` and under
`/nobackup/tasks/jtcores-145/artifacts/v2-7-physical/`.

## Board boot baseline

Use the official Trenz **TEI0022-03 / A5_C8_2GB** reference design for
**Quartus 20.1.1**. This matches the installed `/opt/quartus_free` tools.
The source and prebuilt Linux image are distributed together in
[`TEI0022-test_board-quartus_20.1.1-20220426153922.zip`](https://www.trenz-electronic.de/trenzdownloads/Trenz_Electronic/Development_Boards/TEI0022/Reference_Design/20.1/test_board/TEI0022-test_board-quartus_20.1.1-20220426153922.zip).

The nested archive at
`test_board/prebuilt/A5_C8_2GB/os/yocto/images/tei0022-image-minimal-tei0022-a5-c8-2gb.zip`
contains a complete 357,480,448-byte WIC disk image, including its partition
table. Write the image to the whole microSD device. Its partitions are:

| Partition | Sector start | Sector count | Purpose |
| --- | ---: | ---: | --- |
| 1 | 2048 | 45558 | FAT boot files: FPGA RBF, kernel, DTB, extlinux |
| 2 | 49152 | 2048 | Type A2: raw SPL/U-Boot for the SoC boot ROM |
| 3 | 51200 | 647004 | ext4 Linux root filesystem |

SHA-256 identifiers:

```text
182d6f3017186ddc3e486abf047ca66276462fac67b788367b0c7288838c5d90  vendor ZIP
038649b7a02e982def9e0d79d7146a27b8f3f2be8db0aaa9bbb90a2de5c35891  WIC image
```

With power off, insert the prepared card in **J3** and set **S7-1 ON,
S7-2 OFF** for SD boot. Connect Ethernet and the HPS UART USB connector
**J5**, then power on. The console uses **115200 baud, 8N1**. This specific
stock image uses user **root with an empty password** and DHCP on `eth0`.
It does not include an SSH server; install the development SSH payload offline
or use the serial console for initial access.
The image leaves the remainder of larger cards unallocated.

See the manufacturer's [board manual](https://wiki.trenz-electronic.de/display/PD/TEI0022+TRM)
and [reference-design documentation](https://wiki.trenz-electronic.de/display/PD/TEI0022+Test+Board).
Current online documentation describes newer images, whose login and
filesystem layout differ from this pinned 20.1.1 baseline.

Offline validation checked both archive CRCs, the complete image hash,
the ext4 filesystem with `e2fsck -fn`, boot configuration references,
and console/network configuration. The first physical card write passed a complete image readback comparison.
To use a larger card fully, grow only
partition 3 (keep its start at sector 51200), run `e2fsck` while unmounted,
and expand ext4 with `resize2fs`. Keep both boot partitions unchanged.

The prepared development card has since been expanded to **116.09 GiB**.
Its root partition still starts at sector 51200 and now has 243456000
sectors. Offline filesystem checks passed after expansion.

## Development access

The two micro-USB connectors connect to FTDI UART/JTAG chips: J5 is the
HPS serial console, and J13 selects JTAG targets. They do not expose a
native USB Ethernet gadget connection. The board has no built-in WiFi.
Its other USB ports connect through a host hub; WiFi would require an
adapter with a driver and firmware supported by the installed kernel.
The built-in RJ45 interface already has DHCP configured in the vendor image.

An offline SSH payload is available in the #145 task artifacts. It contains
[Dropbear 2026.94](https://dropbear.nl/mirror/releases/dropbear-2026.94.tar.bz2)
and musl 1.2.5, built as a static ARMv7-A hard-float executable with GCC 10.2.
The multipurpose binary provides the server, host-key generation and SCP.
Password and PAM authentication are disabled at build time; development
access uses this PC's Ed25519 public key. Host private keys are generated
on DataStorm at first boot. A SysV service starts SSH on port 22.

Use `ssh root@BOARD_IP` after DHCP assigns an address. Transfers use
`scp -O FILE root@BOARD_IP:/tmp/`; the payload does not provide an SFTP server.
The serial console remains available independently of the network.

Validation includes static ARM ELF inspection, key generation under QEMU,
a public-key SSH command through the ARM server, a one-MiB transfer into the
ARM SCP receiver with exact data comparison, and rejection of a wrong key
and password authentication. The successful SSH tests used a native
unprivileged account and child shell. Full stock-rootfs login under
proot/QEMU failed at filesystem permission lookups. Physical DataStorm boot,
key-only root SSH and exact SCP upload/readback have since passed on
Linux **5.4.124-altera**. The development board obtained **192.168.68.72** by
DHCP; this address may change. Ethernet negotiated 1 Gbit/s full duplex.
The board exposes approximately 1 GiB HPS RAM and the expanded root filesystem.

## Reproduce the vendor FPGA build

With `setprj.sh` already sourced, pass the pinned ZIP above and a new empty
build directory to the helper. Keep that directory for later compilations:

```sh
bash modules/jttms10/ver/fpga/build-vendor.sh /path/to/TEI0022-test_board-quartus_20.1.1-20220426153922.zip /nobackup/tei0022-build compile
bash modules/jttms10/ver/fpga/build-vendor.sh /path/to/TEI0022-test_board-quartus_20.1.1-20220426153922.zip /nobackup/tei0022-build rapid
```

`prepare` creates only the Quartus project; `generate` also creates the
Platform Designer system. `compile` retains generated IP and the Quartus
database, and `rapid` invokes `quartus_sh --flow recompile`. Every compilation
uses **`/opt/quartus_free`**, including the inherited tool environment.
Platform Designer generation uses the matching 20.1 installation's
`sopc_builder/bin` tools because the wrapper directory has no Qsys launchers.
Commands, logs, elapsed wall time, exit codes and tool version go under
`BUILD_DIR/logs/`. Source ZIP hashes are checked before every action.

The vendor source uses `test_board.bdf` as its top level; the generic board
`top.v` is an empty template. Use the source design's HPS DDR, pinmux and
clock presets. The first build fitted in 2,330 ALMs and 10 RAM blocks.
The fabric's worst reported setup slack was +0.799 ns. Final DDR reports
after calibration have positive margins; negative intermediate paths explicitly
labelled "Before Calibration (Negative slacks are OK)" are not the final DDR
result. The vendor design still reports unconstrained external HPS I/O and
an HDMI PLL constraint warning; this does not establish full board timing closure.

The source design and shipped WIC device tree use different FPGA peripheral
addresses. For example, the rebuilt SYSID is at **0xff210820**, while the
shipped tree describes **0xff201020**. Keep legacy FPGA HDMI/GPIO/DMA drivers
unbound when loading the source build. HPS Ethernet and SD remain available.
The rebuilt image was loaded on the real board and its SYSID **22** and build
timestamp matched the actual compiled `db/ip/.../QSYS_test_board_sysid.v`.
Quartus may regenerate IP during compilation, so use the compiled timestamp,
not the earlier `qsys-generate` timestamp. This prevents bit-identical RBF
reproduction unless that generated timestamp is also pinned.

## Programming through Linux

The vendor kernel supports FPGA programming through configfs device-tree
overlays. A fragment targeting `&base_fpga_region` specifies `firmware-name`
and `fpga-bridges = <&fpga_bridge0>, <&fpga_bridge1>`. Store the RBF in
`/lib/firmware`, unbind FPGA clients, and apply its compiled DTBO with
[fpga-load.c](fpga-load.c). Build it with an ARMv7-A hard-float C compiler;
the development executable is statically linked with musl.

```sh
arm-none-linux-gnueabihf-gcc -O2 -Wall -Wextra -Werror fpga-load.c -o fpga-load
# On DataStorm, after quiescing clients and creating the overlay directory:
./fpga-load image.dtbo /sys/kernel/config/device-tree/overlays/jttms10/dtbo
```

The loader explicitly closes the configfs descriptor while its process is
alive. **Do not use `cat image.dtbo > .../dtbo` on this kernel.** Applying at
process exit triggered a kernel NULL fault in `request_firmware` after the
task's filesystem context had been released. Reboot recovered the board;
explicit close subsequently programmed both the shipped and rebuilt RBFs.
The kernel also warns of property leaks when removing overlays.

The loader's exit status alone is insufficient: check overlay `status` is
`applied`, FPGA manager `state` is `operating`, both bridge states are
`enabled`, and the expected design identifier is readable. Leave clients
unbound on failure. Removing an overlay disables bridges; quiesce clients
before removal as well as before programming. Boot files remain unchanged,
so reboot restores the shipped image.

Initial measurements on this development PC and board:

| Operation | Seconds | Scope |
| --- | ---: | --- |
| Platform Designer system creation | 404.30 | First vendor system |
| Platform Designer HDL generation | 204.78 | First vendor system |
| Full Quartus compile | 440.71 | Four workers; map, fit, assemble, STA |
| Rapid Recompile, no changes | 3.50 | All compilation stages skipped |
| Shipped RBF programming | 0.275 | Target monotonic clock, explicit close |
| Rebuilt RBF programming | 0.281 | Target monotonic clock, explicit close |
| 2 MiB SCP upload | 5.456 | Includes SSH startup |
| 2 MiB SCP download | 2.483 | Includes SSH startup, exact hash match |

These are historical vendor bring-up measurements. The dedicated runner
build and physical regression timings above are separate. Changed-RTL
incremental recompilation benefit and end-to-end speedup against a matched
software matrix remain unmeasured.

## Synthesizable observation interface

Define `JTTMS10_REGRESSION` to expose decode acceptance and accepted PC/IR,
the physical register-file write transaction, selected CPU working state,
pending-field consistency and logical bus start/completion/data through
`jttms10_system`. The macro adds observation outputs; it does not alter CPU
behavior. Normal builds retain their existing port lists.

The register observer reports the existing six-bit physical write address,
including SP aliases and the extended workspace. It adds no RAM read port,
array reset or asynchronous debug mux. The consumer must track which entries
were written in each case; unwritten entries have no defined reset value.
Sample the write transaction and architectural boundary before the edge's
writeback. A snapshot at decode must therefore exclude writes on that same
edge. Bus-start observation requires the timed bus; the raw-bus mode reports
zero on that output.

Check the exposed path with the existing timing fixtures and Python oracle:

```sh
python3 modules/jttms10/ver/fpga/check_observer.py --simulator verilator --case addk
python3 modules/jttms10/ver/fpga/check_observer.py --simulator verilator --case addk --pause-clocks 7
```

The helper derives a temporary bench from `ver/timing/test.sv`. Register
snapshots use a shadow fed only by exposed writes, and decode/bus logs use
the public observer signals. Simulation assertions compare initialized shadow
entries with the real register RAM. Case generation and checking remain in the
existing timing suite. This bench still uses software stimulus and is not the
FPGA batch controller.

Validation so far: strict lint with and without the macro; 192 ADDK cases
with and without a seven-clock CEN pause; and 4,040 mixed MMTM/MMFM/PUSHST,
MOVI and indirect-store cases. The mixed subset's architectural observations,
clock counts, bus traces and target traces exactly match the unmodified bench.
Quartus Analysis & Synthesis on the TEI0022 device with the macro enabled
retains both synchronous 64x32 register RAM mirrors as `altsyncram` and reports
538,624 total block-memory bits. This is an inference check, without a fitted
CPU runner or hardware timing-equivalence claim.

## Source-bound runs and ROM-only updates

Current `run_batch.py` requires a receipt binding the CPU implementation and
its generators to the compiled image. Refresh historical receipts lacking
CPU fingerprints into a new file with `write_programming_receipt.py`, using
the original fitted build and matching checkout; preserve published receipts.
Fixture programs and the independent Python oracle are excluded from this
implementation fingerprint. They can change without recompiling the FPGA.
The same receipt can be used from another checkout with identical inputs.

The writer also accepts an explicit `jttms10-rapid-build-result-v1` certificate
for `/opt/quartus_free/quartus_sh --flow recompile test_board`. It binds the
actual command, whole-flow log and success marker; fresh map, fit, assembly and
STA reports; and the retained parent's result, frozen inputs, image and timing
summary. Both parent and candidate must have positive final STA with zero TNS.
All ordinary source, generated-payload, input-snapshot and image checks remain
active. The runtime receipt records `quartus_flow_kind=recompile`; it does not
relabel the experiment as a full compilation. An elapsed-time comparison alone
does not establish timing closure or a recompilation benefit.

Run the receipt rejection tests with:

```sh
python3 -B modules/jttms10/ver/fpga/test_programming_receipt.py
```

The ROM-only helper below still requires a full-flow parent certificate.
For changes to `ucode/tms10.yaml` that regenerate only `tms10.uc` among the
synthesized artifacts, reuse the fitted database with this limited update:

```sh
fpga_baseline=/path/to/baseline-checkout
fpga_variant=/path/to/changed-cpu-checkout
bash modules/jttms10/ver/fpga/build-rom-update.sh \
    --base-build /path/to/original-fitted-build \
    --source-root "$fpga_baseline" --hardware-source-root "$fpga_variant" \
    --parent-receipt /path/to/source-bound-baseline-receipt.json \
    --build-dir /path/to/new-fit-clone --evidence-dir /path/to/new-evidence \
    --variant my-rom-change --overlay my-unique-overlay \
    --boot-id "$fpga_boot_id"
```

Set `fpga_boot_id` from `/proc/sys/kernel/random/boot_id` on the board. The new build directory must not exist; build/evidence paths must be
separate from the immutable base. The helper does not program the board.
It regenerates the variant, rejects source/template/geometry changes outside
this contract, verifies the fitted main-control MIF against the baseline ROM,
then updates its complete 4096-by-62-bit contents and all three source-ROM
copies. It runs `/opt/quartus_free/quartus_cdb --update_mif` followed by
`quartus_asm --read_settings_files=off --write_settings_files=off`. Default
assembly after CDB failed with error 132003 in this project; retain these flags.

The output receipt declares an inherited fit, not a new compilation or STA.
Ordinary RTL/interface/geometry changes use the full compilation flows above.
Keep the original fitted database, parent receipt and evidence files: runtime
validation needs them. The helper hashes the unchanged fitted-file set and
checks that the only changed generated ROM is the declared main-control ROM.
It imports the adjacent receipt writer so a copy in the DataStorm skill can
operate against an explicitly selected baseline checkout.

Program the uniquely named output RBF with a matching, uniquely named overlay
using the proven explicit-close loader and programming procedure above.
These variants inherit SYSID 22 and the parent's timestamp; those values alone
do not distinguish ROM contents. After verifying image hash, overlay, boot ID,
bridges and SYSID, execute with baseline expectations and variant source:

```sh
python3 modules/jttms10/ver/fpga/run_batch.py /path/to/manifest.json \
    --source-root "$fpga_baseline" --hardware-source-root "$fpga_variant" \
    --receipt /path/to/new-evidence/rom-update-receipt.json \
    --parent-receipt /path/to/source-bound-baseline-receipt.json \
    --artifacts /path/to/results --run-name my-rom-change
python3 -m unittest discover -s modules/jttms10/ver/fpga -p 'test_*.py'
```

The source-bound driver rejects a baseline receipt paired with changed CPU
source, and requires explicit parent/source/image evidence for a ROM variant.
It retains the original oracle and fixture expectations. After negative tests,
restore the original image/overlay and run baseline controls.

Physical checks demonstrate both functional and timing regression detection.
Changing ADDK add to subtract at ROM word 0xc1 makes the selected case return
A0=ffffffff instead of 00000001 and wrong ST at the correct 8 INCLK; NOP and ADD
controls pass. A four-microinstruction NOP at words 0x20..0x23 preserves state
but takes 12 instead of 8 INCLK; ADD passes. Both host commands exit 1. All five
mutant/control observations and expected errors match short original Verilator
runs. Eight baseline executions before/between/after the mutants pass and match
Verilator. The final board state is the restored baseline `datastorm-runtime`.
Evidence is under `/nobackup/tasks/jtcores-145/artifacts/v3-rom-update/`.

The reusable helper reproduced exactly the physical functional-mutant RBF in
61.77 seconds external wall, including generation, fit cloning, CDB, assembly
and receipt checks. Generation/clone/CDB/assembly were 2.03/0.16/27.79/28.38
seconds. It preserved 2,577 fitted-file hashes. Original physical variant host
commands took 6.37/6.39 seconds. These are distinct measurement scopes: the
helper excludes programming and test execution, and the earlier 771.34-second
full fit is not a matched recompilation benchmark. A software speedup and
ordinary changed-RTL Rapid Recompile benefit remain unmeasured.

The copied DataStorm skill driver, using the new source-bound baseline receipt,
also passed all 51,542 supported base cases in 1,665 batches after both mutant
restores, with exit 0 and no reprogramming. Full external host wall was 112.05
seconds; the driver sampled 74.963 seconds before report serialization/stdout
and cleanup. Keep these measurement scopes separate. Evidence is in
`v3-rom-update/skill-bundle-full-matrix/`.
