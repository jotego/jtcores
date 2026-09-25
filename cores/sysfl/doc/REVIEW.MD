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
