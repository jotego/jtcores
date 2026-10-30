# Replacement Rastan history: public interfaces and replay scope

The practical experiment preserves every selected replacement MAME register write, including duplicate1B writes, in one continued YM history. The physical monitor executes bounded tables while retaining chip state; uploads and host waits deliberately expand timing. A controlled target after that prefix is a **new controlled experiment after the complete replacement prefix**, not the original missing98,880-write trace, the natural old event or continuous MAME timing. No RTL or third-party algorithm change is required.

## Primary/public interface review

Yamaha's YM2151 datasheet, printed/PDF page3, identifies the multiplexed D0–D7 bus, A0=0 address/A0=1 data, active-low WR/RD/CS, and active-low IC initialization. It identifies SO and the SH1/SH2 serial-sample controls. Printed/PDF page2 shows the public pin/block diagram. These pages were visually reviewed from `modules/jt51/doc/yamaha/ym2151_datasheet.pdf`; new renders and hashes are under `artifacts/model-history-interface-v1/primary/`. Public register initialization is not asserted equivalent to IC reset or hidden-counter initialization.

| Wrapper | Public input/advance interface | Export used for comparison |
|---|---|---|
| JT51 | `clk,rst,cen,cen_p1,cs_n,wr_n,a0,din`; address/data strobes; polls `dout` busybit7; all master clocks advance | signed `left,right`, `sample`, `clock,status`; `xleft,xright` remain auxiliary |
| External OPM | `OPM_Reset`, `OPM_Write(port0,address)`, `OPM_Write(port1,data)`, `OPM_Read(port1)` busy/status, `OPM_Clock` | public reconstructed DAC pair `dac[0],dac[1]`; internal inc/phase columns are excluded from acceptance |

Frozen production JT51 is985a573dcfc1ff135553a39f7eae21d18ba57cbe. External OPM isa0ab44be60cb28b68431779829454ddf3284f272; its header declares Nuke.YKT copyright and LGPL2.1-or-later. Its implementation remains in the external checkout. This review inspected public declarations and our own wrappers only; no external implementation logic was copied.

The old wrappers' write routines are at `tasks/jtcores-143/ver/jt51/test.cpp:94` and `ver/opm/test.cpp:51`. The former logs beginning of the JT51 public DATA strobe; the latter logs OPM API data presentation. Neither proves internal acceptance or physical bus phase. OPM uses one API advance per two input master clocks,32 API calls/native stereo frame. JT51 captures its native sample strobe. Both retain64×stride clock cadence, execute all skipped clocks, use exclusive outputs, and finish the complete EVENT even if the finite sample limit is reached earlier. Physical IRQ is not observed.

## Why the old commands alone cannot replay the prefix

Both old `read_program` functions reject files over8192 bytes. Monitor bytecode is END00, WRITE01/reg/value, DELAY02/low/high, STATUS03. A98,880-write tape needs at least296,641 bytes before delays; the selected209,206-write replacement needs at least627,619. It cannot be passed as one old PROGRAM/INIT/EVENT file. Separate executable invocations also reset each model and lose history.

The installed monitor has an8KiB TABLE window at logical8000/physical4000 (MPR4=02), control at2000 and communications at3C00. The monitor itself runs from sound RAM, so the host may upload/readback a new table while it is idle, then publish generation/complement. Each completed command returns three bytes and consumes three recorder markers. No ordinary table command resets the YM or CPU. Its instruction fetcher has no stream watermark, ring wrap or host-pause/deadline opcode. Overwriting a table while it executes is not a safe streaming protocol.

The physical backend is a28-pin P28/27C51264KiB mapping, not an assertion that the entire device holds only8KiB. The current qualified command window is8KiB; expanding banks or continuous FIFO scheduling would require separately prepared firmware/protocol qualification. It is unnecessary for the explicitly expanded-timing experiment selected here.

## New-task state-isolated frontend

`tasks/jt51-13/scripts/monitor.py` and `pico_link.py` are byte-identical copies of the owned qualified helpers. Their location makes ROOT and mutable state resolve to this new task. `history_frontend.py` uses only those copies and rejects a state/output root outside jt51-13. Do not invoke the old monitor/capture CLIs: they write mutable locks/state into the sealed143 task. ROOT separately owns the new capture-event copy and analyzer.

TSV contract, shared with the new public model adapters:

```text
program	gap_before_master_clocks
/ABS/chunk000.bin	0
/ABS/chunk001.bin	358000
```

The header is exact; paths are absolute. The nonnegative integer is a requested gap **before** that row. Each file must be1..8192 bytes, end exactly at END, contain valid complete opcodes, and the whole input is limited to2,000,000 writes. Header-only history supports a fresh control. There is no implicit gap after the final row. SHA256 values and all literal write counts are frozen before execution.

Offline/new-task commands:

```sh
python3 tasks/jt51-13/scripts/history_frontend.py --validate --history /ABS/history.tsv
python3 tasks/jt51-13/scripts/history_frontend.py --adopt-state /ABS/verified-idle-snapshot.json
```

Adoption is an exclusive host-state copy and does not open USB; it is not a fresh board qualification. ROOT alone may execute the reviewed live command:

```sh
PYUSB_PYTHON tasks/jt51-13/scripts/history_frontend.py --execute --history /ABS/history.tsv --ROOT-binding /ABS/ready.json --output /ABS/FRESH-report.json
```

The binding contains `authorized_by=/root`, strict true `authorize_history_once`, frontend/history/state hashes, initial generation/marker count, expected boot-bank hash and reserved markers. Before upload, the frontend checks P28/protocol/ROM geometry, boot/control identity, idle reply producer and complete marker budget. Each chunk is copied to a fresh report folder, uploaded/readback-verified using the unchanged helper, committed once and polled to completion. Failure retains pending/failed evidence and stops; it never resubmits, reloads ROM, resets the CPU or rearms automatically.

The report retains submit/reply host bounds, ROM API upload/readback/generation-commit bounds and Pico completion-marker snapshots. These are not accepted YM-write timestamps. Requested gaps are lower-bounded host sleeps; upload and reply latency adds further time. A later ROOT-approved model schedule may choose nominal integer gaps within the observed uncertainty. It must retain those bounds and cannot be called exact physical timing.

Offline validation passed11 fake-Pico lifecycle/negative tests using the unchanged copied monitor body and no USB endpoint. It covers state persistence/generation wrap, wrong-reply stop/no retry, readback failure/no generation commit, boot/marker/input failures, sealed-root rejection, malformed bytecode, whole-input bound, header-only history and exclusive state adoption. The real replay-01 TSV validates80 rows:313 initialization writes plus79 source chunks/107,500 source writes. All chunks fit8191 bytes. One initial test oracle omitted the existing magic/control reads; the source/log are retained and the test expectation was corrected. One summary initially conflated the79 source chunks with the added initialization row; the actual frontend validation itself exited0. No protocol or input was changed for either correction.

## Whole-model replay adapter and exact command contract

New-task copies under `tasks/jt51-13/ver/{jt51,opm}` were independently implemented and qualified by the clean-room interface child. They add `--history FILE.tsv` and optional `--delay-clocks32|37.5`; all prefix rows and target INIT/EVENT run in **one** model instance. Legacy no-history32 behavior retains byte-identical outputs in the bounded qualification. Every file and the combined2M-write bound is prevalidated before model construction/output. Builds and outputs stay under the new task, never the sealed task's fixed build directories.

The qualified command interface is shown below. For a frozen science batch, use the compiled binaries pinned by `artifacts/model-history-validation/handoff.json` directly; do not rebuild through sim.sh while jobs are running:

```sh
bash tasks/jt51-13/ver/jt51/sim.sh --history /ABS/schedule.tsv --delay-clocks 37.5 --stride 1 --event /ABS/end.bin /ABS/event.bin /ABS/NEW-jt51.csv 16384
bash tasks/jt51-13/ver/opm/sim.sh --history /ABS/schedule.tsv --delay-clocks 37.5 --stride 1 --event /ABS/end.bin /ABS/event.bin /ABS/NEW-opm.csv 16384
```

In history mode there is **no legacy4096-master-clock implicit settling interval**. If a target INIT→EVENT/ARM wait is required, place target INIT in the history rows and an END-only row after it with the explicit gap, then use END-only as CLI INIT. This makes the intended wait visible. A fractional carry is retained across programs: JT51 advances integer master clocks; OPM preserves its two-master-clock API cadence and reports the remainder. Default32 and legacy CLI behavior stay unchanged. Capture sample/stride bounds remain10,000,000 retained frames and16,777,216 native frames.

The37.5 parameter approximates the monitor's delay loop only. It does not replace the CPU's dispatch/get-byte/address/data/busy overhead with the model's own write overhead. The compiler's source4MHz interval mapping,80-clock allowance, rounded delay counts, physical uploads and chosen model gaps therefore define an **expanded approximate schedule**, not a timestamp-faithful4MHz replay. Source-cycle preservation would stretch nominal wall time by4MHz/3.58MHz and lower oscillator pitch; exact elapsed-time and source-cycle preservation cannot both be assumed. Neither hidden counter phase nor equal accepted-write time follows from identical register lists.

ROOT's selected natural replacement target follows the complete107,500-write prefix and a1200-write EVENT. The controlled AR12/ALG0 and rawRR0 targets are distinct stimuli after that prefix, with matched fresh controls and declared phase delays. Preserve that distinction in labels. The finite capture can end before EVENT finishes; all writes must still execute, while any analysis/post-tail claim must use its actual horizon. No full-song, recovered-original identity, direct waveform equality or new numerical agreement band is implied.

## Completed adapter qualification and target orchestration

The wrapper qualification finished with508/508 checks over82 bounded tiny-program
processes. It covers legacy steady/event byte identity at strides1/3, persistent
split/flat histories at32/37.5, carry/gaps, zero implicit settle, input/write
bounds, exclusive output and CLI failures. Public step/write/busy bodies are
unchanged; these checks do not constitute a full replacement-history run.
The six sources and two executables are pinned in
`artifacts/model-history-validation/handoff.json`
(SHA2569cf3ced69d99b954e772a6b41d20c1bd4160f2593f382822b4e07fef36f94112).

`scripts/run-models.py` freezes completed physical case metadata and literal
programs before a ROOT-approved batch. Its model schedule uses the generation
commit API midpoint minus the prior reply-host end, rounded at3580000 clocks/s.
All API endpoint intervals and a conservative completion-to-next-commit outer
interval remain in the plan. The first row has no physical reset/age-equivalence
claim. Final waiting uses EVENT commit midpoint minus INIT submission reply end;
no implicit settling is introduced. Three concurrent compiled models are the
ROOT-approved operational limit. Raw-energy descriptors use the public left/right
columns, with no alignment or conformance threshold.

The disjoint frozen plans cover20 controlled cases/40 models in batch01,
16 controlled cases/32 models in batch02 and six final natural stride3 cases/12
models in batch03. The final target catalog therefore has42 cases and84 whole
model executions. The earlier natural stride1 attempts are excluded from this
primary catalog and retained with their finite-horizon limits. Actual terminal
records, independent saved-output audits and the final joined index determine
completion; preparing a plan alone is not execution. The source/proposal and10
offline orchestration tests are retained separately.

The original interface-report bytes are retained as
`artifacts/model-history-interface-v1/model-history-original.md`, resolving the
original interface-provenance hash after this intentional status update.
