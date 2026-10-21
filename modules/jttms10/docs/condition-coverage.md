# Remaining timing-condition audit (#144)

All 133 instruction forms have probes. That inventory answers whether an
encoding has tests; it does not establish every documented timing condition.
The policy-aware source gate also passes, while retaining the explicit
[project choices](source-policy.md). Neither gate sets `full_isa_signoff`.

This table records the tested domains and the remaining work. A documented
condition in the last column is an acceptance requirement, not an exclusion
created to make the existing suite pass. Individual source-linked reports
contain the equations, fixtures and source revisions for their bounded results.

| Area and primary source | Committed coverage | Remaining acceptance work |
| --- | --- | --- |
| Scalar arithmetic, multiply, shifts and divide: SPVU001A instruction entries, §§12.10/13.1 | Field widths, signs, destination parity, aliases, exceptional divide paths, cached/CD counts and deterministic early waits/CEN; [multiply](multiply.md), [divide](divide.md), [main ledger](timing.md#coverage-ledger) | Audit each conditional table rule against actual fixture axes, including cache/peripheral and pending-interrupt interactions. Passing arithmetic results alone do not qualify timing. |
| Branches, calls, returns and register lists: §§8/12/13.1 | Both branch paths/conditions, targets, counts, stack words, following consumers and explicit source interpretations; [control](control-timing.md), [calls](call-timing.md), [lists](list-timing.md) | Complete cold/prefetch/cache-conflict and last-state interrupt/HOLD audits. RETI PBX continuation has graphics tests, but the scalar RETI family does not independently prove every resumption timing rule. |
| MOVE/MOVB and hidden writes: Tables13-1..4, §§5.4/6.2/11.3/13.1.1 | Width/alignment, addressing forms, overlaps, aliases, literal examples and dependent loads. Native CD byte nominal/following/HOLD and instruction-word dependencies have [separate checks](movb-cd-timing.md). | Consecutive posted writes, broader consumers/contention, cached self-modification rules, complete cache replacement/prefetch and interrupt recognition during posted work. The qualified HOLD family has no derived total HOLD-adjusted instruction duration. |
| PIXT reads: §§7.3/12.10 | Linear/XY reads, pixel sizes, legal lanes, planes, source pitches/offsets and following loads; [linear](pixel-read-timing.md), [XY](pixel-xy-read-timing.md) | Finish condition/bus/IRQ audit, including cache/peripheral interactions. Retain documented undefined alignment and source-example distinctions. |
| PIXT writes and DRAV: §§7/12.10/13.1 | Linear replace/Boolean PPOP0..15 at PMASK0/T0; XY and memory-to-memory replace subsets; [linear write](pixel-store-timing.md), [XY write](pixel-xy-store-timing.md), [DRAV](draw-timing.md) | Arithmetic processing, plane masks, transparency, SRT, window modes and their combinations; dependent instruction and interrupt timing. |
| FILL L/XY: §§12.10/13.3, Tables13-5..7 | Replacement A/B/C/D edges and constant-alignment rows; complete-word Boolean PPOP1..15 at PS1/2/4/8/16 and arithmetic PPOP16..21 at PS4/8/16; [FILL](fill-timing.md) | Partial Boolean/arithmetic words, masks, transparency, XY window preclipping, changing row alignment, empty/negative dimensions where specified, and broader dimension/pitch boundaries. Table dashes and estimated/average counts need explicit interpretation before exact goldens. |
| FILL interrupts: §13.3.4 and §§8.5/8.6 | Architectural replacement/Boolean/arithmetic IRQ/NMI continuation, preserved destination order/memory and PBX frame; bounded replacement timing through the FPGA event checker | Source-backed Boolean/arithmetic word/row checkpoint bounds, exact context/RETI and resumed work timing under waits/CEN/HOLD. Architectural continuation does not prove these timings. |
| PIXBLT six forms: §§12.10/13.4, Tables13-8..13 | Aligned opaque W0/PBH0/PBV0 regular and binary rows, bounded dimensions/offsets/pitches, plus regular/binary IRQ continuation; [PIXBLT](blit-timing.md) | Partial/long binary rows beyond the qualified domain, masks, transparency, processing, windowing, reverse traversal and other documented conditions. Audit exact resumed timing and combined stalls. |
| LINE: §§12.10/13.5 | Bounded replace-only W0/W2/W3 probes, deterministic waits and continuation; [LINE](line-timing.md) | Processing/mask/transparency/SRT conditions, broader error/count/window boundaries and exact interruption/resumption timing. |
| Cache, bus and host interface: §§5.4/6/11 | Directed misses/fills, timed bus minimum/ready sampling, response retention, RMW restart, host I/O and no-stack NMI I/O fixtures | Complete cache replacement/prefetch, simultaneous-owner/contention and peripheral event audit. The logical interface does not reproduce original electrical pin edges or separate LRDY/data timing. |
| Interrupt acceptance and external stalls: §§8/11/13.1.2 | Scalar IRQ/NMI phases, aligned/unaligned context, priorities, no-stack modes, deterministic stimulus and explicit context boundaries; FPGA event suites | Audit every instruction-specific recognition rule, combinations with cached/posted work and graphics, and every documented HOLD/restart boundary. Keep base instruction counts strict. |
| Normal runner and clean CI | Permanent architecture/model/unit/mutation/timing checks in `ver/run.sh`; standalone FPGA transport uses the same independent Python expectations | Complete current-source normal and clean-checkout/CI invocations. FPGA matrix results do not by themselves establish completion of every normal-runner stage. |
| Physical implementation and NARC | DataStorm appliance builds and source-bound runtime evidence; historical CPU/NARC validation | Final matched fitted CPU ceiling of 3,500 ALMs, positive constrained 20 ns CPU/board timing, NARC simulation with meaningful frames/audio, and MiSTer gameplay after implementation changes. Appliance STA is a separate check. |

For the next unqualified condition, first add cited independent expectations
and boundary fixtures, preserve a failing baseline, then change the native
schedule. Keep architectural state, memory and physical bus checks active.
Use short Verilator representatives and deliberate functional/timing mutations;
run large supported inventories on the DataStorm after source/image identity
and representative agreement checks. Programs and supported stimulus settings
change at runtime; changes to the CPU RTL require a new reviewed image.

Unsupported transport settings must fail explicitly. They do not remove the
corresponding legal instruction condition from #144. Record genuinely
undefined TI behavior and conflicting printed rules separately from missing
implementation or missing tests.
