# System FL 60.000 MHz hardware review — `4b4ecf403`

Reviewed on 2026-09-27: `4b4ecf4039a61f9d5c7ef57b6877f192e8e0cef2`, branch `nsr`. Inspection and focused probes used an isolated archive of that commit. This report is saved on the current branch; no RTL or constraints were changed. The older `885d37e3c` review is retained below as historical context.

## Ranked findings

| Rank | Finding | Evidence | Explains WORK RAM NG and fast hangs? |
| --- | --- | --- | --- |
| 1 | MiSTer DDIO phase and controller first-beat latency disagree | Reproduced with the repository's Micron model | Yes: incorrect SDRAM read words; fitted delays can change the observed capture slot |
| 2 | Refresh PRECHARGE-to-REFRESH remains one cycle | Reproduced command trace; violates slow-part `tRP` | Yes: repeated out-of-spec memory operations |
| 3 | SDRAM I/O is unconstrained; pad clock has an unsafe fallback and clock-group exclusion | Source verified; actual fitted margins unavailable | Yes if an input, output, or mask timing limit fails |
| 4 | CPU MC3/MC2 exceptions cover ungated IRQ and cache-clear paths | Source verified; actual failing routed path unproven | Hangs plausible; ordinary WRAM POST failure is a weak match |
| 5 | Initialization wait still assumes the old frequency | Source verified; board startup may mask it | Conditional cold-start corruption; weak match for this repeatable symptom |

### 1. High: the DDIO hardware path selects a first-beat strobe one clock late

**Locations:** `modules/jtframe/target/mister/target.def:1`; `cores/sysfl/cfg/macros.def:43,53`; `modules/jtframe/hdl/jtframe_board_sdram.v:113,243-247`; `modules/jtframe/target/mister/hdl/jtframe_emu.sv:320-323`; `modules/jtframe/hdl/sdram/jtframe_sdram64_bank.v:82-86`; `modules/jtframe/hdl/sdram/jtframe_sdram64.v:190-196`.

MiSTer's target definition contributes `JTFRAME_SHIFT=1`. The core contributes `JTFRAME_180SHIFT=1`. The wrapper XOR therefore selects **`SHIFTED=0`**, not 1. The DDIO cell drives 0 on the base rising edge and 1 on its falling edge: the SDRAM rising edge is nominally half a base period after the controller launch. Meanwhile `SHIFTED=0` selects `DST=READ+2`.

Let E0 be the base edge registering READ onto the pins. SDRAM accepts READ at E0+T/2. In the repository Micron CL2 model, the first word launches on the following SDRAM edge, E1+T/2, plus `tAC` (`mt48lc16m16a2.v:814-821,343-347,1090-1102,1187`). With `tAC=6 ns` and T=16.666 ns, D0 reaches the model pins before E2. The controller captures D0 into `dout` at E2. The current `SHIFTED=0` controller exposes `dst` after E3, so the consuming slot samples at E4 and receives E3's `dout`: **D1, not D0**. `SHIFTED=1` exposes the strobe after E2 and the consumer uses D0 at E3.

A focused Icarus probe instantiated the unmodified bank FSM and supplied Micron model, plus register stages matching the controller's `cmd`, `dout`, and `dst` assignments. It did not instantiate a full game or fit the I/O cells. Mode word `13'h222` selects CL2, sequential BL4 reads, and single writes; memory words were `1111,2222,3333,4444`. Both command and capture clocks ran at 60 MHz. Results:

| Pad phase | Controller `SHIFTED` | First consumed word |
| --- | --- | --- |
| Inverted base, actual DDIO phase | 0, actual MiSTer macro result | `2222` — FAIL |
| Inverted base | 1 | `1111` — PASS |
| Normal base, simulation phase | 0 | `1111` — PASS |

**Why the reported simulations miss it:** sidi128 resolves `JTFRAME_SHIFT=0` and negates `JTFRAME_180SHIFT`, leaving `SHIFTED=0` with a normal pad phase. That is the passing third row, not the first. Matching the core's frequency and memory configuration does not exercise the hardware phase relationship.

**Symptom match:** this can make a 16-bit WRAM read return the adjacent halfword and shift a 32-bit cached fill by one beat. Both POST comparisons and game state/instruction reads can fail. This is broader than a WRAM-only write defect: ROM/cache fills share the path too. If the fitted design boots far enough to show POST, its real clock and DQ delays may move some captures into the following base slot; the focused result is a demonstrated phase/latency inconsistency, not proof of the exact on-board waveform. Depending on such delays to choose the correct beat is unsafe.

**Minimal RTL fix:** for the single-rate DDIO path, select the first-beat latency that corresponds to the actual pad waveform; the focused probe requires `SHIFTED=1`. Make that selection explicit in the wrapper rather than inheriting the normal MiSTer PLL-path `JTFRAME_SHIFT` XOR. A core-local `JTFRAME_SHIFT=0` override would produce that parameter today, but a named RTL phase/latency selection is clearer. Align `dst`, `dok`, `rdy`, and BL4 bus-occupancy guards together. Then establish a valid physical DQ capture window as in finding 3. This does not establish that an unchanged positive-edge input capture meets fitted timing.

### 2. High: `CMDW` fixes bank commands but misses the refresh precharge interval

**Locations:** `modules/jtframe/hdl/sdram/jtframe_sdram64_rfsh.v:25-26,88-104`; `modules/jtframe/hdl/sdram/jtframe_sdram64.v:151-154,196,270-281`; `modules/jtframe/hdl/jtframe_board_sdram.v:141-145`; compare `jtframe_sdram64_bank.v:72,79-82`.

At 60 MHz the controller remains `HF=0`. Its refresh FSM still has `RFRSH=1`, so PRECHARGE ALL and the first AUTO REFRESH are issued on consecutive SDRAM rising edges. The top-level command register delays both equally; the DDIO phase does not increase their separation. A focused trace of the unmodified refresh FSM, the top command register/mux, and an inverted pad clock measured:

```text
pad PRE:                  199.992 ns
first pad REF:            216.658 ns
PRE -> REF:               16.666 ns
successive REF -> REF:    83.330 ns
```

The slow 512-Mbit Alliance `-7` specification requires `tRP=21 ns`, explicitly including precharge-to-refresh; `tRFC=63 ns`. Thus this sequence violates `tRP` even though the normal bank PRECHARGE/ACTIVE sequence now has two-cycle spacing. [Alliance timing table, page 22](https://www.alliancememory.com/wp-content/uploads/AllianceMemory_512M_SDRAM_Bdie_AS4C32M16SB-7TXN-6TIN-7BIN__Rev1.4_June2024NK.pdf)

**Mechanism and symptom match:** refreshing while all-bank precharge is incomplete puts the SDRAM outside its specified operation. Failed refresh or subsequent bad accesses can corrupt WRAM and hang either game. This recurs during POST and gameplay; it is not merely an initialization risk. The historical HF path gives two precharge clocks, explaining the improvement in the stable 48/96 regime, although that field result is not a guarantee for every slow part.

**Why simulation misses it:** `modules/jtframe/verilator/sdram.cpp:22-24` explicitly omits `tRP`, `tRCD`, and `tWR` enforcement. The separate Verilog Micron model defaults to fast-bin `tRP=15 ns` at `mt48lc16m16a2.v:292-305`, which would also permit this interval unless overridden.

**Minimal RTL fix:** derive refresh precharge and recovery waits from the actual clock and supported chip limits. For this build, `RFRSH=2` and `STW=7` give 33.3 ns PRE-to-REF while preserving the current five-clock/83.3 ns repeated-refresh spacing. **Changing only `RFRSH` to 2 with `STW=6` shortens repeated REF spacing to four clocks/66.7 ns.** Prefer independent `ceil(tRP/T)` and `ceil(tRFC/T)` parameters; do not couple device timing solely to HF/SDRAM96.

### 3. High physical risk: the passing STA result does not validate SDRAM I/O

**Locations:** `modules/jtframe/target/mister/syn/sdram_clk48.sdc:4-10`; `modules/jtframe/target/mister/hdl/sys/sys_top.sdc:13-22`; `cores/sysfl/syn/timing.sdc:1-38`; `modules/jtframe/hdl/sdram/jtframe_sdram64.v:195,204-221`; `modules/jtframe/target/mister/hdl/pllc6000/pll/pll_0002.v:37-54`.

The active non-SDRAM96 files create a pad clock but contain **no SDRAM `set_input_delay` or `set_output_delay`**. Creating a clock on `SDRAM_CLK` does not supply the SDRAM's clock-to-DQ delay, hold, setup, PCB flight times, or module loading. The reported +0.258/+0.184 ns therefore does not establish the external read/write interface margins.

After correcting beat alignment, a positive-edge capture half a period after SDRAM data launch has a nominal setup remainder of `8.333 - tAC`. CL2 `tAC(max)=6 ns` leaves only **2.333 ns** for pad-clock output delay, board travel, FPGA input timing, and relative clock uncertainty. The same manufacturer's `tOH(min)=2.5 ns` also needs to be modeled, especially if retaining the later capture slot in finding 1. The 180-degree polarity is not inherently wrong, but it is not a timing guarantee at 60 MHz. [Alliance AC limits and read waveform, pages 22 and 25](https://www.alliancememory.com/wp-content/uploads/AllianceMemory_512M_SDRAM_Bdie_AS4C32M16SB-7TXN-6TIN-7BIN__Rev1.4_June2024NK.pdf)

The write command, DQ, and mask also launch together on the base positive edge and are sampled at the following pad rise. A late DQ or DQM bit writes old data or selects the wrong byte. The real inout/OE path differs from Verilator's separate `sdram_din` port (`jtframe_sdram64.v:174-176,209-218`). This explains both WRAM NG and hangs if fitted I/O timing is bad, but no routed netlist or measured pad timing was available to identify a specific failing bit.

**UNSAFE constraints:**

- `sdram_clk48.sdc:7`: the fallback describes the pad as in phase with PLL output 1. In `pllc6000`, output 1 has zero phase, while the active DDIO pad is inverted relative to output 0. If this fallback is selected, its clock description is wrong by half a period. Line 9 has the intended 180-degree phase only if the matched counter really drives `clk_rom`. Which branch executes requires the fitted clock report.
- `sys_top.sdc:13-22`: the explicit game clock group matches PLL clock names, not the separately named `SDRAM_CLK`. TimeQuest cuts unlisted clocks from explicit clock groups; without explicitly grouping the pad clock with its base, a pad-clock-to-base I/O transfer can remain cut even after input/output delays are added. [Intel/Altera clock-group semantics](https://docs.altera.com/r/docs/683068/18.1/intel-quartus-prime-standard-edition-user-guide/creating-clock-groups-set_clock_groups)
- `sdram_clk48.sdc:4-10`, as the complete SDRAM constraint file: missing external delay limits are a coverage defect, not a timing pass.

**Minimal hardware fix sketch:** retain the base-domain command launch, capture DQ in an explicit input register at a phase with measured setup/hold margin, and retime the captured words and valid strobes together. Hold selected write data/mask/OE in a register bundle before issuing WRITE if the existing launch mux fails its real output budget. Accurate pad-clock and min/max I/O constraints are required to verify these RTL changes; they are tightening the analysis, not an SDRAM timing waiver. No RTL edit alone makes absent I/O constraints validate the board.

**Placement check:** the generic MiSTer `sys.tcl:95-97`, sourced by `mister.qsf:51`, already requests fast output, output-enable, and input registers on SDRAM ports. The stale specific `dq_ff` assignment at `mister.qsf:64` does not prove the actual `sdram64:dout` register is unconstrained for placement. The earlier review's inference from commented-out general assignments was incomplete. Verify actual fitter packing, particularly because bank 0 write capability defaults on and bank 3 also writes.

### 4. Medium: IRQ and cache-clear paths do not obey blanket CPU multicycle assumptions

**Locations:** `cores/sysfl/syn/timing.sdc:4-6,18-20,34-38`; `cores/sysfl/hdl/i960/jt960.sv:125-148,314-321,338-346,351-369,524-526,780-781`; `modules/jtframe/hdl/jtframe_edge.v:18-28`.

Each nested `u_irqlatch[*]|u_edge` has `edge_l` and `q` registers that sample every base clock, not just `cpu_cen`. They match the blanket `u_cpu|*` collection but not its one-clock patch list. Pending IRQ changes feed the free-running `s1_irqt`, `s1_vec`, and `s1_line`. An event can update pending at E1, stage at E2, and be consumed at the next enable E3: those particular legs have one actual clock, while the blanket and stage exceptions offer two or three. Self-feedback/edge detection within the nested latch is also clock-rate logic.

`ic_clr` is asserted on a CPU enable but cleared on the very next base edge. The ungated sweep logic must see that one-clock pulse at the next base edge. Its paths to `sweeping`/`swa` are omitted from the fast source list. The list restores paths *from* those sweep registers, which does not restore paths *into* them from `ic_clr`.

**UNSAFE:** the broad MC3 setup/hold pair at lines 5-6 and MC2 stage pairs at lines 35-38 when applied to these paths. The restored RAM and fast-source constraints at lines 12-13 and 19-20 tighten timing; they are not themselves extra waivers. The register-cache MC2 at lines 26-27 has the intended cen-registered-address rationale, but that does not cover nested IRQ latches.

**Why simulation misses it / symptom match:** ideal RTL timing cannot reproduce a late pending/vector or missed invalidation. Both games can hang if those paths are routed beyond their actual one-clock deadlines. This is a weaker explanation for a plain WRAM data-test mismatch and is not demonstrated to explain both symptoms.

**Minimal RTL fix:** cen-align IRQ edge/pending updates and hold the resulting IRQ snapshot across intervening clocks; System FL IRQ levels remain asserted until acknowledgement. Make cache-clear a held request consumed/acknowledged on an enable edge, or make its full-rate receiving path explicitly single-cycle. Do not add an exception to accommodate a late one-clock pulse. Actual endpoint collections and routed path delays still need inspection.

### 5. Low: initialization wait is too short as a standalone slow-part contract

**Location:** `modules/jtframe/hdl/sdram/jtframe_sdram64_init.v:19,33-42`; `jtframe_sdram64.v:146`.

`HF=0` waits 5,000 clocks: 83.3 microseconds at 60 MHz. The sampled 512-Mbit slow-part datasheet requires 200 microseconds of stable startup clock before normal initialization, and specifies the initial CKE/DQM conditions; the controller drives CKE high continuously. [Alliance power-up sequence, page 23](https://www.alliancememory.com/wp-content/uploads/AllianceMemory_512M_SDRAM_Bdie_AS4C32M16SB-7TXN-6TIN-7BIN__Rev1.4_June2024NK.pdf)

**Mechanism:** cold power/configuration can issue PRECHARGE/mode/refresh before startup has completed. The model does not simulate supply ramp or this startup contract. A normally powered MiSTer module may already have been stable for far longer before the core releases reset, so this is not evidence that the observed run violates startup timing. It is a weak match for a repeatable 60 MHz-only gameplay failure.

**Minimal RTL fix:** derive the stable-start interval from actual MCLK and the supported part (at least 12,000 cycles for 200 microseconds at 60 MHz, plus margin), and size the counter for other frequencies. Gate CKE/startup appropriately for a genuine cold-start controller.

## Suspects verified SAFE, or not established as causes

- **Normal bank `tRP`/`tRCD` at 60 MHz — SAFE for the sampled 20–21 ns limits:** macro generation resolves `JTFRAME_MCLK=60000000`, hence `CMDW=2`; PRE-to-ACT and ACT-to-column are each 33.3 ns (`jtframe_sdram64_bank.v:72,79-82`). The first finding from the older snapshot has been fixed here. The same change did not reach the refresh FSM.
- **Single-beat writes under BL4 — SAFE by mode selection:** `jtframe_sdram64_init.v:72` sets M9 for single-location writes. Four read beats do not require four write data beats.
- **Write recovery and normal turnaround guards — no command-level violation established:** write completion returns through READ/IDLE; registered busy and DQM guards block immediate new column transfers (`jtframe_sdram64_bank.v:136-146,163-181`). The traced normal write-to-precharge spacing is at least two clocks/33.3 ns; BL4 `in_busy64` guards the full read tail before a write. This does not clear physical DQ/OE timing or the wrong beat alignment.
- **Repeated refresh recovery — SAFE for the cited 63–66 ns limits:** five clocks/83.3 ns between consecutive refresh commands. Maintain that interval when fixing PRE-to-REF.
- **Refresh rate scaling — SAFE; not fixed to 48 MHz:** `macros.go:474-487` derives the divider from MCLK. At 60 MHz it emits `N=1`, `M=1920`, `WC=11`, giving a 32 microsecond debt trigger, with default nine refreshes per trigger. Nominal service is 281,250 refresh commands/s versus the 128,000/s requirement (8192/64 ms), about 2.2 times the minimum; idle batching can issue one extra command. This is roughly 2–3% bus occupancy, not massive over-refresh. Debt/help arbitration bounds postponement. The wrapper's 64-microsecond comment is stale.
- **PLL frequency and enables — SAFE in the reviewed configuration:** PLL outputs 0/1 are 60 MHz at zero phase; the DDR pad gets its inversion from DDIO, not output 1. Outputs 4/5 are 120 MHz but SDRAM96 is absent, so neither supplies the controller/pad. `mem.yaml:16-28` gives CPU 20 MHz, XIN 16 MHz, and C352 24 MHz. With no busy gate configured, CPU enables have three-clock spacing. `jtframe_pxlcen.v:15-17,28-32` selects M=5 and divides its second enable by two, yielding the intended 6 MHz pixel rate.
- **Macro placement — SAFE as placement, but exposes finding 1:** generated MiSTer values include `180SHIFT=1`, `MR_DDRLOAD=1`, `SHIFT=1`, MCLK 60 MHz; sidi128 has `180SHIFT=0`, `SHIFT=0`, and the same frequency. Global DDRLOAD remains enabled and controls the DDR ROM-load proxy (`jtframe_mr_ddrmux.v:34-37,54-67`), not the running SDRAM pad phase.
- **SDRAM96 capture multicycles — INACTIVE here:** `target/mister/cfg/files.yaml:47-52` includes `sdram_clk48.sdc` when SDRAM96 is absent. The exceptions in `sdram_clk96.sdc` cannot explain this exact build. No explicit active SDRAM-DQ false path or multicycle was found in the non-96 file; missing delays and the clock-group cut remain unsafe.
- **C355 packing — SAFE in the inspected concatenation:** `jtc355_scan.sv:88,235-237,287-300` packs/unpacks exactly 150 bits with matching field boundaries. Record validity/count reset before use (`252-257`). Decode starts after eight blank line strobes, while the snapshot copy takes about 5,632 clocks, under two 3,840-clock lines (`jtc355.sv:98,112-132`; scan `518-522`). This covers normal uninterrupted vblank DMA, not every ioctl interruption. No cause of WORK RAM NG was established; this rewrite postdates the observed hang.
- **Existing shadow/code-fetch exception — still a secondary logical flaw:** `jtsysfl_main.v:112,158-159` allows WRAM instruction fetches through wram32 regardless of dirty shadow or an active posted write. Protect code fetches with the data-load dirty/pending checks. It can explain stale executed code, but not an ordinary WRAM data POST failure or a hardware-only discrepancy by itself.

## Verification limits and next discriminating checks

The review reproduced the pad-phase first-word discrepancy and the refresh command interval with focused timing-aware probes, not a new full-game run or a Quartus fit. Actual source generation confirmed the target macros. No installed chip marking, compiled QSF/SDC endpoint collections, fitter I/O-register report, or pad measurement was available. The +0.258/+0.184 figures were supplied by the user and were not independently reproduced.

First validate the exact build's `SHIFT/180SHIFT/SHIFTED` values and capture DQ/READ/dst together under the actual pad phase. The phase mismatch predicts adjacent-word or shifted-burst data, not only random write loss. Independently fix refresh PRE-to-REF spacing. Then report real min/max SDRAM pad timing and clock transfers; the current internal timing summary cannot distinguish successful timing closure from an unmodeled memory interface.

---

# Archived review — `885d37e3c`

The following historical report describes the earlier snapshot. Its bank command-spacing finding is superseded by `CMDW` in the current tree. Its write-register placement discussion omits the port assignments in `sys.tcl`; use finding 3 above for the corrected placement audit. Its startup example used a different device minimum; use the supported installed part's specification.

# System FL hardware crash hunt — adversarial review

Reviewed snapshot: `885d37e3cd8ff2af04d9633a2d5afa4678a7e1df` (2026-09-25). This is a source-level review of the 60 MHz, single-rate `jtframe_sdram64` configuration. It does not establish the installed SDRAM speed grade, fitted I/O placement, or on-board timing. The source snapshot was inspected in an isolated copy; this report is saved on the current `nsr` branch.

## Ranked findings

### 1. High: row-miss command timing can violate SDRAM limits at 60 MHz

**Locations:** `modules/jtframe/hdl/sdram/jtframe_sdram64_bank.v:66-76,140-171`; `modules/jtframe/hdl/jtframe_board_sdram.v:141-145`; `cores/sysfl/cfg/macros.def:50-58`.

Without `JTFRAME_SDRAM96`, the board wrapper selects `HF=0`. For a row miss with no competing-bank stall, the bank state machine registers PRECHARGE, ACTIVE, then READ or WRITE on consecutive base-clock edges. Both PRECHARGE-to-ACTIVE (`tRP`) and ACTIVE-to-column (`tRCD`) therefore get one 60 MHz cycle, **16.67 ns**. The [Micron MT48LC16M16A2 timing table](https://datasheet.lcsc.com/lcsc/2409302135_Micron-Tech-MT48LC16M16A2P-6A-G-TR_C2062032.pdf) specifies 18 ns for `-6A`, 20 ns for `-75`, and 15 ns for `-7E` for both limits. Thus the code violates the first two speed grades if either is installed; the chip marking must be checked before calling this the observed hardware cause.

An SDRAM that has not completed precharge or row activation can return old/incorrect data or write the wrong location. The work RAM POST crosses rows repeatedly; later corruption can affect either game's control flow. Zero-delay RTL and typical behavioral SDRAM models do not model an analog failure from a short `tRP`/`tRCD` interval. At 48 MHz the same one-cycle interval is 20.83 ns, explaining why this constant could have looked safe there.

**Minimal RTL fix:** insert an idle command cycle after PRECHARGE and after ACTIVE for the 60 MHz configuration. Parameterize those waits by the supported device's `tRP` and `tRCD` instead of coupling them to the SDRAM96/HF switch. Keep read-data phase selection independent.

### 2. High physical risk, unconfirmed: DQ/DQM write launch has a half-cycle pad budget

**Locations:** `modules/jtframe/hdl/sdram/jtframe_sdram64.v:18-23,160-164,174-176,185-221`; `modules/jtframe/target/mister/hdl/jtframe_emu.sv:299-330`; `modules/jtframe/target/mister/mister.qsf:64-68`; `cores/sysfl/cfg/macros.def:43-44,56-60`.

The WRITE command, DQ data, and MiSTer DQM values are all registered on one base-clock rising edge. The DDIO SDRAM pad clock rises about half a cycle later. At 60 MHz, the selected write value and mask have about **8.33 ns** total for FPGA clock-to-output, routing, board delay, and SDRAM setup. The controller's default enables bank 0 writes, while System FL also enables work RAM's bank 2, leaving a bank-select mux on the DQ/DQM inputs. The QSF explicitly requests a fast *output-enable* register for DQ, while its general fast output-register assignment is commented out; this does not prove where the data registers were fitted.

If one DQ or DQM bit arrives late, the SDRAM captures an old bit or the wrong byte mask on a work RAM write. This matches intermittent POST failure and eventual hangs. Verilator uses a separate `sdram_din` output instead of the real inout/tri-state pad path and has no board delays or contention, so its passes do not clear this risk. **This finding is a physical timing candidate, not a demonstrated bad fitted path.**

**Minimal RTL fix sketch:** register the chosen bank data, mask, and output enable together, then issue the WRITE command from that held bundle one base cycle later. If required, use an explicit Cyclone V I/O-register structure in RTL. Inspect the fitted DQ/DQM register locations and I/O timing to confirm the mechanism.

### 3. Medium: CPU multicycle exceptions include registers that update every base clock

**Locations:** `cores/sysfl/syn/timing.sdc:4-20,29-38`; `cores/sysfl/hdl/i960/jt960.sv:123-150,307-369,780-781`; `modules/jtframe/hdl/jtframe_edge.v:16-29`.

The blanket `u_cpu|*` exception gives internal register paths three clocks, and the `s1_*` exceptions give two. Yet each IRQ latch's `edge_l` and `q` update on every base clock, with no `cen`; they are not in the one-clock source list. An IRQ arriving between CPU-enable edges can update `q` at edge E1, be sampled into `s1_irqt` at E2, and affect a CPU register at the next enable E3. Both legs may have only one real cycle even though the relevant exceptions allow more. The one-clock `ic_clr` pulse likewise feeds the ungated cache-sweep logic and is absent from that source list. These are concrete holes in the exception premise, although a fitted timing report is needed to establish an actual failing path.

Late paths can miss or mis-handle an interrupt or cache invalidation, consistent with a minutes-scale hang. RTL simulation uses ideal register timing. This is a weaker direct match for a work RAM POST error.

**Minimal RTL fix sketch:** make the IRQ edge latch `cen`-aligned so its pending result remains stable across the intervening base clocks. Hold cache-clear requests until the sweep FSM acknowledges them on a `cen` edge. Recheck every always-clock CPU source before relying on the blanket exception; do not add another timing waiver.

### 4. Medium logical bug, lower POST match: dirty work RAM code fetches bypass the shadow

**Locations:** `cores/sysfl/hdl/jtsysfl_main.v:112-126,128-159,287-305,366-385`; `modules/jtframe/hdl/sdram/jtframe_romrq_bcache.v:49-71`.

The shadow marks a `wram32`-cached word dirty when the CPU writes that 32-bit word. Ordinary data loads then use the 16-bit funnel. `is_code`, however, feeds `is_w32` regardless of `sh_dirty` or an outstanding posted write. If the CPU writes a word still held by the two-entry `wram32` cache and then fetches it as code, the cache can return the old instruction. The shadow's intended first-write-wins rule is not applied to that fetch. The code can also launch a `wram32` fetch while the posted write is still in the funnel.

This is a deterministic logical flaw. Two-state RTL simulation does not intrinsically hide it; the reported runs can pass if they do not exercise that exact write-then-fetch sequence. It is a plausible later hang, but does not by itself explain an ordinary work RAM *data* POST read failure.

**Minimal RTL fix:** gate code fetches with the same dirty/pending-write conditions as data loads, and route protected fetches through the 16-bit funnel until the posted write completes.

### 5. Lower: SDRAM initialization count assumes 48 MHz

**Location:** `modules/jtframe/hdl/sdram/jtframe_sdram64_init.v:19,37-73`.

The single-rate path waits 5,000 clocks before its first PRECHARGE: **83.3 µs** at 60 MHz, although the source comment calls it 100 µs at 48 MHz. The [Micron initialization requirement](https://www.alldatasheetru.com/html-pdf/75881/MICRON/MT48LC16M16A2/2299/12/MT48LC16M16A2.html) is 100 µs after power and clock become stable before commands other than NOP/inhibit. Reset and PLL startup may already contribute enough elapsed time, so the controller's short count is not proof of a board-level violation and is a weaker fit for crashes after minutes. Behavioral simulation may not enforce the power-up interval.

**Minimal RTL fix:** derive the counter from the actual base clock and include margin above the device minimum.

## Suspects checked as safe in the inspected logic

- **BL4 versus a single write beat:** the mode word in `jtframe_sdram64_init.v:72` sets M9 for single-location writes. Driving DQ for one beat per WRITE is intentional; the four-beat setting applies to reads.
- **Write-to-precharge/write-to-read command ordering:** `jtframe_sdram64_bank.v:140-170` returns through IDLE after a write, with no immediately following one-clock command in the traced bank path. This logical check does not establish DQ pad turnaround margin.
- **Ordinary data-load shadow and byte lanes:** `jtsysfl_main.v:158-165,293-315,366-384` resets shadow validity, marks matching writes dirty, selects the 16-bit funnel for dirty data loads, and carries the selected low/high `dsn` to the write port. The code-fetch exception is finding 4.
- **Reset/first use in inspected paths:** the shadow valid bits and block-cache `good` bits reset; the block cache's unreset `addr_l` is captured on a request before fill; `jt352`'s unreset mix pipeline is written in INTP before MIX consumes it (`jt352.v:253-261`). No first-use fault was established there. This does not prove all C75 internal RAM contents are initialized by firmware.
- **HPS/ioctl crossing into this path:** MiSTer's `hps_io` is driven by `clk_rom` (`jtframe_mister.sv:497-514`), the clock used by the SDRAM board logic. No separate unsynchronized HPS-to-work-RAM crossing was found in the traced interface. The external SDRAM pad remains a phase/timing problem rather than an independent asynchronous domain.

## Most useful next observations

1. Read the SDRAM chip marking and its `tRP`/`tRCD` speed grade.
2. Inspect the Quartus fitter's DQ data/output-enable register placement and DQ/DQM output timing relative to the DDIO SDRAM clock.
3. For the CPU exception, list actual `u_cpu|*` register endpoints and inspect the IRQ-latch and `ic_clr` paths in TimeQuest.

The work RAM bank in this reviewed commit is **bank 2** (`cores/sysfl/cfg/mem.yaml:55-68`); the “bank 1” comment in `jtsysfl_main.v:40` is stale. The findings concern the shared 60 MHz design and do not depend on that layout change.
