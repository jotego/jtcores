# Linear memory-to-memory pixel replace timing

This subset covers `PIXT *Rs,*Rd` with PPOP=replace, PMASK=0, T=0 and aligned
1/2/4/8/16-bit pixels. TI SPVU001A pp.12-220/221 requires four visible CPU
states, three hidden write states for partial-word pixels and one for 16-bit
pixels; CD counts are10 and 8. All GPRs and ST bits are preserved. Window
checking does not apply. FS/FE and array corner flags are ignored.

The p.12-221 example with PSIZE=16 and destination 20508 is not pixel-aligned,
contradicting the explicit linear-address alignment rule on p.7-10. Under
the owner's simpler-implementation fallback, the domain follows that rule;
the inconsistent example is excluded, not relabeled as a compliant timing
case. The four aligned replace examples remain literal oracle vectors.
The implied-operand list's PSIZE=6 is likewise outside the legal size set.
No official TI correction is claimed.

The native path reads the source pixel, then posts it through the existing
field engine to the old destination pointer. Register pointers remain
unchanged, including aliases/shared SP. Original source memory supplies the
pixel even when source/destination share one word. Source/target bus cycles
remain distinct. Existing MD/EA and read-to-post handoff metadata are reused;
no DSP, register bank or arithmetic unit is added. The original opcode family
112 dispatches to scalar entry151 for this subset. Other PPOP/mask/
transparency/SRT and interference/HOLD/IRQ/cache/resumption conditions remain
unvalidated; this is not full graphics or ISA timing signoff.

An independent bit extractor and insertion walk calculate source pixels and
preserved destination memory. The explicit transport contract allocates the
source read at state 1 and the first posted transfer at state 3. Every physical
transfer takes two states plus W waits. Hits charge source-read waits to the
four CPU states and hide trailing writes; CD waits for writes and the next
opcode. After K cached NOPs, a real following load starts at
`max(4+W+K,3+W+T*(2+W))`,where T is the posted transfer count. Logical and raw
request/ACK/IAQ/address/data/order/duration checks remain active. TI specifies
totals/hidden states; first-slot allocation is the project's transport rule.

The prefill program from [pixel-boolean-timing.md](pixel-boolean-timing.md)
skips the measured transfer,warms its opcode/tail and restores following-load
state before the first actual copy. This also avoids a second-pass overlap
changing the source data. All 31 distinct GPRs, full ST and sparse memory are
checked. Cache/tag guards preserve the warm-hit assumptions.

The 5,856 fixtures cover every legal source/destination lane pair in distinct
words and one shared word, both banks, all 16 source/pointer identities and
aliases, ignored FS/FE/window/corner settings, source/destination patterns,
flags/IE, high/wrapped addresses, all four opcode phases, 70 real following
loads and all four aligned literal examples in both cache modes. Historical
136 representative probes on unchanged 3cdbdd220 fail timing/bus with correct
architecture/memory; all 22 old HDL/YAML hashes verify. They are evidence,
never oracle input or an expected-failure allowlist.

Three actual RTL mutants lengthen the CPU tail, delay the source read or lose
the inherited write slot. Correct architecture/memory cannot waive their
timing failures. Four response-event probes retain a real source response
arriving during 96 CPU-disabled clocks,then verify ordered posting and final
memory. That CPU-only overlapping-pause event contract is separate from
TI's exact unpaused/early-pause instruction counts.

Reproduce from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case pixel_copy_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_copy_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_copy_ --simulator verilator --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/load_pause/check.py --case pixel_copy_
python3 modules/jttms10/ver/timing/mutations.py
```

The standard runner includes the new fixtures, word-phase union, response cases
and mutations. Full clean/remote CI, remaining ISA/conditions, known MOVB targets,
final fitted area/board STA and NARC/MiSTer acceptance remain open under #144.

Targeted validation passes all 17,568 programs in three profiles; a detached
clean checkout repeats them, 179 models and 37/1 response events with exact
case objects, 53 source/seven generated hashes and response objects. All 394
representative Icarus stress cases match Verilator except batch-local ID,
alongside 102 short phases, two fresh processes, 180 architecture programs,
strict lint and the original 38-request MSW-first assertion. Three new and
11 affected timing mutation controls/rejections preserve correct state/memory.
All 112,874 preceding fixture contracts remain unchanged. The initial wrong
family dispatch aborted its first batch case; that prototype is excluded.
Matched map estimates 3,909 ALMs, 5,643 ALUTs, 1,722 registers and five DSPs;
all 36 snapshot/29 committed physical inputs verify. No new fit/STA is claimed.
The full runner frozen cabaf7c8b is complete:361,988 exact timing programs
(3x118,730+2DIV+6x966phase),179 models,180 architecture,699 bus,93 mutation
controls/101 rejections,response37/1,EMU8/1 and the original MSW-first assertion.
All53 source/seven generated hashes match the commit/map,with unchanged whole
private Git tree. Supervisor exit1 is solely12 missing forms/448 unresolved
MOVB probes,including45 agreed targets. Clean scope remains targeted17,568
programs/models/events,not a full361,988-program clean normal runner. Full
clean/remote CI and final hardware/game acceptance remain open.
