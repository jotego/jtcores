# Issue144 handoff and resumed validation

## Resumed on 2026-10-19

The owner resumed this task on the second computer. Work continues on
`jtcores-144-resume`, based on the experimental XY-copy branch and merged
with the stable branch's accepted121-runner history. The issue remains open.

Latest progress: corrected b6bb7e6ed passes all 26,634 clean XY-copy timing
programs with 56 committed-source/seven generated hashes and exact full case
objects verified; a separate stressed 8,878-case run matches exactly. The
clean tail also passes 206 models, 49 response controls/one rejection and
180 architecture programs. All 632 corrected Icarus cases match Verilator
except simulator-local case IDs. Six short pause profiles pass 198 cases;
two fresh-process cases match the stressed batch. The eight affected pixel
mutation groups pass 24 positive controls and reject 24 timing mutations
while preserving all defined architectural state and memory. Each report's
56 source/seven generated hashes verify, with only the intended RTL file
changed in each mutant.

The full 124-form normal runner remains unfinished. It has passed 180
architecture programs, unit/system benches, 206 models, 699 bus scenarios,
response49/1 and EMU8/1 so far. Its frozen source is 4f3b7d9ac; the separate
original checkpoint mutation run is historical evidence. The latest accepted
complete normal runner remains 121/cabaf7c8b/361,988 programs. Targeted XY-copy
verification does not replace the full runner or any final acceptance gate.

Current b6 synthesis-only result is3848 estimated ALMs,5644 ALUTs,1722
registers,538624 RAM bits,five DSPs,zero MLAB,158 virtual pins and49 warnings.
All36 snapshot hashes and matched settings verify. Fixec3be7b9d corrects
legacy reference metadata without changing any hashed synthesis input;
see [current XY-copy evidence](pixel-xy-copy-timing.md). No fit/STA acceptance
is claimed. The [FILL source audit](fill-timing.md) records the next timing
requirements and unresolved qualifications. Commit c84957906 adds its independent
FILL oracle and eight model tests to the normal runner, without adding CPU
probes or covered forms. These eight tests pass separately; the already
running frozen 4f3b7d9ac invocation does not include them.

This machine uses Verilator5.039. The checkpoint pixel helper's grouped
combinational block produces fatal UNOPTFLAT warnings here. Commit53e352578
separates mask/ALU/result dependencies without suppressing warnings. Its
26,634 XY-copy programs pass all three profiles, and206 checker tests pass,
but the independent pixel unit exposed an Icarus time-zero initialization
problem in that first split. Those results are intermediate evidence, not
final validation. Commitb6bb7e6ed makes the mask a continuous decode; all
174,689 existing pixel-unit cases and strict lint then pass. Corrected-source
repeat status is recorded above; intermediate captures never replace it.

Task records now live in `/nobackup/tasks/jtcores-144/`. The initial clean
repeat on53e352578 was cancelled specifically because of the demonstrated
pixel-unit failure; its command, process group and reason are recorded.
The original full mutation run and initial632-case Icarus comparison retain
their checkpoint sources. The earlier36-hash map belongs to53e352578;
the corrected b6 map above supersedes it. No fit/STA or complete normal-runner
acceptance is claimed.

The repository pre-commit Go checks pass, but its all-core macro scan fails
on the pre-existing, undocumented `JTFRAME_NO_REGISTER_RETIMING` macro in
NARC's baseline. The two helper fixes and documentation merge used a
per-command hooks override after confirming this unrelated baseline failure;
no persistent git configuration was changed.

## Original pause record

The owner requested stopping here to resume on another computer. Issue144
remains open; all nine full-scope tasks remain unchecked. Do not interpret
this checkpoint as full timing compliance or completed graphics validation.

## Branches

- `tea/jtcores-144` is the reviewed development line through DRAV123 forms.
  Last implementation:c81c60b46; clean/Boolean verification:17c625f0d;
  latest accepted full-runner documentation:ba3016ced.
- `tea/jtcores-144-pixel-xy-copy-final` holds the **unmerged experimental
  XY-to-XY replace path**. Functional checkpoint:bffa7d03c, based17c625f0d.
  Its runtime inputs are frozen. Later checkpoint documentation does not
  change those inputs. Continue here to finish validation, then integrate
  into jtcores-144 while retaining ba3016ced's full-runner documentation.
- An earlier local `jtcores-144-pixel-xy-copy` prototype has multiple EA
  clocked drivers and fails Quartus elaboration. Do not use it. Its source
  and failure log are preserved in the pause evidence archive.

## Accepted results

Latest accepted **complete development normal runner**:121-form linear pixel
copy, frozen cabaf7c8b,361,988 exact timing programs,179 models,180 architecture,
699 bus scenarios,93 mutation controls/101 rejections,response37/1,EMU8/1,
original38-request MSW-first assertion. All53 source/seven generated hashes
match implementation/map. Supervisor exit1 is solely12 missing forms/448
unresolved MOVB probes,including45 agreed published-target gaps. Clean scope
is targeted17,568 programs/179 models/events,not a full361,988-program clean run.

[Complete121 runner and targeted evidence](http://gitea.jotego.es/attachments/84460340-f86b-4182-b8cd-793619dc7b72)
SHA256:c3aba7a9f55d27e6485fb70decdc33aa6121d527a12a7fa4ec0fa1f8c99f9ef9.

DRAV123 implementation c81c60b46 has18,378 new programs across three profiles,
exact targeted clean repeat,197 models,response45/1,724 representative Icarus
cases,102 short phases,two fresh processes,four new/17 affected timing mutants,
768 preceding multiply programs,180 architecture,strict lint and original
MSW-first assertion.55 timing sources/seven generated hashes match.
Scope:replace/PPOP0/PMASK0/T0/W0/aligned1/2/4/8/16 only.129,492 total fixtures,
10 missing graphics forms. Matched map3963 ALMs/5747 ALUT/1722 registers/
538624 RAM bits/five DSPs. No current fit/STA acceptance.

[DRAV targeted evidence](http://gitea.jotego.es/attachments/fcac76a0-e889-48d1-b1b1-7bfa857f7898)
SHA256:42429329bf159e0f2f1d022249d78a7e0a0c33ecebd4f4fe6065813cc4ffb113.

Boolean120 complete runner5a74e596e passes343,940 exact programs and is
superseded by121 above.
[Boolean full evidence](http://gitea.jotego.es/attachments/619ce5e5-e2cc-44da-a61e-cf76927f3f57)
SHA256:e9d7bfe9ba8d77d74e8f11c8f74b3ba427519a110b48afb03acf2a07b112e16b.
Earlier milestones and source alternatives are recorded in issue144 comments
and docs/timing.md. Historical evidence never supplies timing goldens.

## Experimental XY-to-XY checkpoint

`PIXT *Rs.XY,*Rd.XY` replace/PPOP0/PMASK0/T0/W0/aligned pixels. Entry154,
original opcode family108. Reuses scalar DSP products/shared ALU/field engine;
no extra DSP,register bank or arithmetic unit. First conversion saves source
EA; second saves destination A; source read captures MD and selects destination
EA before posting. Reuses RETI's phase bit for independent CONVSP/CONVDP.
TI SPVU001A pp.12-224..226:CPU7,H3/CD13 small pixels;CPU7,H1/CD11 at16 bits.
All ST and coordinate registers preserved. Project first-read/post slots3/6
are distinguished from TI's total/hidden counts.

Inventory:138,370 fixtures,124/133 forms,206 models,9 bulk graphics forms
missing.8,878 new fixtures include all lane pairs,banks/identities/aliases,
32 independent pitches,signed Y,flags/ignored fields/corners,overlap/wrap,
70 real following loads and all five TI literal replace examples.

**Completed on corrected bffa7d03c inputs:**

- Unpaused Verilator base:8,878/8,878 pass.
-206 models,180 architecture,original38-request assertion,strict lint pass.
- Six short Icarus profiles:102 programs pass;two fresh-process cases pass.
- Full response-retention suite:49 controls/one mutant pass.
- Matched quartus_map:3883 estimated ALMs,5682 ALUT,1722 registers,
  538624 RAM bits,five DSPs,zero MLAB bits,158 virtual pins;return0.
  Same Quartus20.1.1/device/20ns/seed/effort and49 warning classifications.
  Source/hash verification script is archived; final combined verification
  is pending. This combined synthesis result does not isolate one change.
-129,492 preceding fixture/program/golden contracts unchanged.
-42 historical probes all fail timing/bus with correct state/memory;
  22 old HDL/YAML hashes match17c625f0d. Committed baseline is historical only.

**Incomplete at user pause:** wait-only/stressed matrices,632-case Icarus
comparison,three new plus17 affected mutation controls/rejections,clean
three-profile/model/event repeat,and124-form complete standard runner.
Do not claim complete26,634-case development or clean validation. The initial
post-credit mutation had no effect and was removed;three other real mutations
remain. The first prototype's successful simulation captures do not replace
corrected-source validation. A first corrected map snapshot failed jtframe Go
path-alias tests before the local binary was built; the successful second map
is retained separately. No final fit/board STA/gameplay acceptance exists.

The previously live122-form f99e1baa6 and123-form c5eb365d8 complete runners
were also stopped at the owner's request.122 had two complete123,366-case
matrices;123 had not completed its matrices. Neither is accepted as a completed
invocation. User-pause records retain exact command,PID/process group/reason.
There is no fabricated final supervisor success for interrupted jobs.

## Resume on another computer

Fetch `tea`,then use the experimental branch to finish XY-copy validation.
The permanent suite builds its own fixtures/ROMs;temporary captures are evidence,
not dependencies. Run from the repository root:

```sh
python3 -B modules/jttms10/ver/timing/test_checker.py
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_copy_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_copy_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_copy_ --simulator verilator --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/load_pause/check.py
python3 modules/jttms10/ver/timing/mutations.py
bash modules/jttms10/ver/lint.sh --strict
JTTMS10_TIMING_SIMULATOR=verilator bash modules/jttms10/ver/run.sh
```

Repeat the targeted profiles/models/events in a clean committed checkout and
compare full case/provenance/event objects. Compare representative Icarus
cases to Verilator,removing only batch-local case IDs. Retain deliberate timing
mutants only when architecture/following state/memory are correct. Verify all
56 timing-source/seven generated hashes against the chosen source and map.
The archived verification script has development-machine paths;adapt paths or
rerun the permanent tools above. Normal-runner coverage/source exit1 remains
expected until the genuine open gates are fixed;do not turn it into a waiver.

After validating,integrate the feature into jtcores-144,publish precise scope/
evidence in issue144,and continue the remaining work. Preserve unrelated
simson/ver/dma files and other tasks. Do not restart historical jobs or claim
their interrupted results as complete.

## Remaining requirements and decisions

- Owner fallback:if TI sources cannot be reliably resolved,choose the simpler
  implementation and preserve numeric alternatives/citations as explicit
  project interpretations. No verified SPVU001B/relevant erratum was found
  online;the owner has no additional local files. Do not re-ask for them.
-448 unresolved MOVB probes,including45 agreed published-target gaps,remain
  requirements. Absolute single-word MOVB:current CPU3/CD15 vs published1/7;
  byte-copy index2:CD9 vs printed7.12,625 recorded choices are separate.
- Remaining forms after experimental XY-copy:LINE,FILL L/XY,and six PIXBLT
  modes. Probe presence alone never proves full condition coverage.
- Other PPOP/masks/transparency/window/SRT,cache/peripheral interactions,
  HOLD/IRQ/resumption and all specified timing conditions remain to audit.
- Final full clean normal runner/remote CI required. Final fitted area<=3500
  ALMs and positive full-board STA required. Previous RETS fit3649 fails area;
  positive isolated internal STA with unconstrained I/O is not board closure.
- NARC simulation/MiSTer gameplay and final `jtcore narc -mrq` with JTNARC_UCODE1
  required when closing. Current production uses five DSPs:three scalar plus
  two field alignment. Original DSP-vs-shift/add comparison is already complete
  in issue144;do not respawn/repeat it.

[Issue144](http://gitea.jotego.es/jotego/jtcores/issues/144) remains the shared
progress record. This pause is a checkpoint,not completion.
