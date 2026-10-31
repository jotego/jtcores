# HD6309 opcode, addressing, mode coverage

## Scope and status

This is a row-by-row view of legal MAME opcode/addressing forms and Atkinson timing baselines. The inventory contains 450 instruction/addressing rows over 439 legal opcode bytes: 442 numeric source baselines, one minimum-duration SYNC row, four TFM formula rows, and three legal MAME dispatches with no published Atkinson timing entry (NEGW, ASRW, ASLW). It records directed-test evidence separately from the generated timing sweep.

The latest focused HD6309 simunit PASS uses the CPU and directed-test hashes recorded below under the expanded sweep. It checks the 96-case DIVD/DIVQ/MULD sign matrix, 160 boundary/hard-overflow cases, zero-divisor sign exclusion, and the divide-zero and TFM behavior described below. The MC6809 timing simunit also passes with the same CPU source. The native taken long-conditional cases match Atkinson’s 5-E HD6309 baseline; six legal W unary opcode/mode cells remain without a published timing baseline.

- `T` in E/N test status: functional and timing assertions for this form were exercised in a passing `hd6309_timing` run; that evidence is tied to the exact source hashes below.
- `X` in E/N test status: the directed simunit ran the form and an assertion failed.
- `F`: functional behavior was checked without a cycle assertion for this form.
- `U`: no matching directed timing or functional test has been identified.
- Sweep `P`: the generated timing vector matched the timing oracle and any checked flow endpoint for that mode. `X`: a vector ran and a timing, dispatch, or flow assertion failed. `U`: the timing comparison was unavailable or its oracle remains unresolved; the vector may still have checked flow. A sweep does not assert architectural result values.

The expanded sweep snapshot below records its own result and source hashes. Interrupt and wait tests check functional frame/vector behavior; cycle assertions are included only where identified in the per-form table.

## Oracle and provenance

- Decode legality comes from local MAME `src/devices/cpu/m6809/hd6309.lst`; explicit dispatch labels are page `$00`: 237 (235 complete instruction opcodes plus prefix selectors `$10/$11`), page `$10`: 121, and page `$11`: 83. The 768 possible page/opcode values therefore contain 327 unmapped values; excluding the two prefix selectors leaves 439 complete legal instruction opcodes.
- Timing pairs and addressing baselines come from Darren Atkinson, *Motorola 6809 and Hitachi 6309 Programmer’s Reference* (2009), consolidated table printed pp. 145–148 and relative table p. 149. The indexed postbyte increments come from p. 150. Source page is included per row.
- Atkinson is the primary behavioral oracle for HD6309 register-register arithmetic. Its printed p. 143 specifies destination-width results and condition-code ordering; local MAME differs for mixed-width register promotion and CC update behavior. The implementation follows Atkinson where these sources conflict, and directed tests cover CC destinations and mixed widths in both modes.
- The original Hitachi HD63B09E/HD63C09E scan is `tasks/jtcores-142/artifacts/hd63c09e-datasheet.pdf`, printed pp. 301–306 (PDF pp. 25–30). It cross-checks original base opcode forms/counts, but gives neither native-mode slash pairs nor HD6309-only timing. Atkinson is the native-mode oracle in this checkout.
- The [6809Decoder source](https://github.com/hoglet67/6809Decoder/blob/master/src/em_6809.c) models original-device bus samples for immediate DIVD/DIVQ divide-by-zero: handler at 23/24 E in emulation and 25/26 E in native, first stack write at 7/8 E, and vector-high read at 20/21 E in emulation or 22/23 E in native. The [HD6309 behavior notes](https://github.com/hoglet67/6809Decoder/wiki/Undocumented-6309-Behaviours#tfm) report the measured same-register `TFM X+,X+` sequence: read `$2000`, write `$2001`, then read `$2002`, write `$2003`, with X ending at `$2200` for the full example.
- The same original-device [DIVD/DIVQ/MULD measurements](https://github.com/hoglet67/6809Decoder/wiki/Undocumented-6309-Behaviours#divd) report one extra E cycle for each negative DIVD/DIVQ operand (dividend and divisor), with no such correction for divisor zero, and two extra E cycles for MULD if either or both operands are negative. The directed test checks every sign pair, addressing form, and MD mode (3 instructions × 4 forms × 4 sign pairs × 2 modes = 96 cases).
- Original-device DIVD/DIVQ overflow behavior uses quotient magnitude: DIVD soft overflow covers magnitudes 128–255 and returns the magnitude in B with N=1,V=1,C=quotient bit 0; DIVQ soft overflow covers 32768–65535 and returns the magnitude in W with N=0,V=1,C=quotient bit 0. DIVD hard overflow is magnitude >255; DIVQ hard overflow is magnitude >65535. Hard overflow preserves the absolute dividend in D/Q and sets N to the dividend sign, Z=0,V=1,C=0. The directed test exercises both sides of each signed/unsigned boundary across four forms and both modes, plus non-boundary hard overflow cases with nonzero remainders.
- For MULD, the original-device decoder preserves C while updating N/Z. Atkinson's individual MULD entry likewise specifies only N/Z changes, while its consolidated table has a C=0 cell; directed tests follow the physical result and individual instruction entry.
- The original-device decoder leaves I/F unchanged for reserved-vector illegal-opcode and divide-zero exceptions. Directed checks start with I/F clear and verify both stacked and live handler CC in those paths.
- The directed test also checks memory-form zero traps against the same decoder schedule: DIVD handler totals are 25/26, 26/27, and 25/27 E (emulation/native) for direct, extended, and indexed `,X`; DIVQ totals are 26/27, 27/28, and 26/28 E. It checks each final divisor-byte read, first stack write, vector-high read, saved CC (`$85` DIVD, `$8D` DIVQ), and preserved D/W. The HD6309 behavior notes report that a normal TFM completion sets Z and interrupted or illegal TFM clears Z; directed cases seed Z and check both outcomes.
- A `+` indexed base requires the matching postbyte increment. DIVD/DIVQ overflow and divide-by-zero, stack-mask byte costs, RTI `CC.E`, TFM transfer count, and long-branch conditionals are stated in the condition column. Immediate and memory DIVD/DIVQ zero-divisor trap phases are checked separately by the directed test using the original-device 6809Decoder bus schedule. Atkinson p. 149 note 11 limits the taken-only sixth long-branch cycle to the 6809; native HD6309 taken conditional branches use the 5-E base, matching MAME.

## Per-form coverage

`E status` and `N status` record directed-test evidence from the latest passing snapshot above. They apply to the source timing values in their columns. Repeated opcode rows preserve aliases and conditional forms. `—` in the condition column means no additional timing rule was recorded for that row. `Bytes` includes any page prefix.

| Page/opcode | Form | Addressing/postbyte class | Bytes | E cycles | E status | N cycles | N status | Sweep E | Sweep N | Condition/formula | Atkinson source | Evidence |
|---|---|---|---:|---:|:---:|---:|:---:|---|---|---|
| `$00/$3A` | ABX | inherent | 1 | 3 | T | 1 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$89` | ADCA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$99` | ADCA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A9` | ADCA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B9` | ADCA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C9` | ADCB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D9` | ADCB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E9` | ADCB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F9` | ADCB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$89` | ADCD | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$99` | ADCD | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A9` | ADCD | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B9` | ADCD | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$31` | ADCR | register_postbyte | 3 | 4 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$8B` | ADDA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$9B` | ADDA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$AB` | ADDA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$BB` | ADDA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$CB` | ADDB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$DB` | ADDB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$EB` | ADDB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$FB` | ADDB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C3` | ADDD | immediate | 3 | 4 | T | 3 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$D3` | ADDD | direct | 2 | 6 | T | 4 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$E3` | ADDD | indexed | 2+ | 6 | T | 5 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$F3` | ADDD | extended | 3 | 7 | T | 5 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$8B` | ADDE | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$9B` | ADDE | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$AB` | ADDE | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$BB` | ADDE | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$CB` | ADDF | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$DB` | ADDF | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$EB` | ADDF | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$FB` | ADDF | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$30` | ADDR | register_postbyte | 3 | 4 | T | 4 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$10/$8B` | ADDW | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$9B` | ADDW | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$AB` | ADDW | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$BB` | ADDW | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$02` | AIM | direct | 3 | 6 | T | 6 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$62` | AIM | indexed | 3+ | 7 | T | 7 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$72` | AIM | extended | 4 | 7 | T | 7 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$84` | ANDA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$94` | ANDA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A4` | ANDA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B4` | ANDA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C4` | ANDB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D4` | ANDB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E4` | ANDB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F4` | ANDB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$1C` | ANDCC | immediate | 2 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$84` | ANDD | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$94` | ANDD | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A4` | ANDD | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B4` | ANDD | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$34` | ANDR | register_postbyte | 3 | 4 | T | 4 | T | P | P | — | 145-148 summary table | latest 479ca860 focused simunit; E,F and CC-target cases PASS |
| `$00/$48` | ASLA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$58` | ASLB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$48` | ASLD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$08` | ASL | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$68` | ASL | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$78` | ASL | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$47` | ASRA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$07` | ASR | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$67` | ASR | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$77` | ASR | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$30` | BAND | immediate_postbyte | 4 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$31` | BIAND | immediate_postbyte | 4 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$34` | BEOR | immediate_postbyte | 4 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$35` | BIEOR | immediate_postbyte | 4 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$85` | BITA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$95` | BITA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A5` | BITA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B5` | BITA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C5` | BITB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D5` | BITB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E5` | BITB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F5` | BITB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$85` | BITD | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$95` | BITD | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A5` | BITD | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B5` | BITD | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$3C` | BITMD | immediate | 3 | 4 | T | 4 | T | P | P | Atkinson p. 34 fixes 4 cycles in both modes; low operand bits ignored | p. 34 HD6309 instruction-set timing table | latest 479ca860 focused simunit: emulation/native BITMD status and 4-cycle checks PASS |
| `$11/$32` | BOR | immediate_postbyte | 4 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$33` | BIOR | immediate_postbyte | 4 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$4F` | CLRA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$5F` | CLRB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$4F` | CLRD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$4F` | CLRE | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$5F` | CLRF | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$5F` | CLRW | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$0F` | CLR | direct | 2 | 6 | T | 5 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$6F` | CLR | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$7F` | CLR | extended | 3 | 7 | T | 6 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$81` | CMPA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$91` | CMPA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A1` | CMPA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B1` | CMPA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C1` | CMPB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D1` | CMPB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E1` | CMPB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F1` | CMPB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$83` | CMPD | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$93` | CMPD | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A3` | CMPD | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B3` | CMPD | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$81` | CMPE | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$91` | CMPE | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$A1` | CMPE | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$B1` | CMPE | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$C1` | CMPF | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$D1` | CMPF | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$E1` | CMPF | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$F1` | CMPF | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$37` | CMPR | register_postbyte | 3 | 4 | T | 4 | T | P | P | — | 145-148 summary table | latest 479ca860 focused simunit; E,F and CC-target cases PASS |
| `$11/$8C` | CMPS | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$9C` | CMPS | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$AC` | CMPS | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$BC` | CMPS | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$83` | CMPU | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$93` | CMPU | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$A3` | CMPU | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$B3` | CMPU | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$81` | CMPW | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$91` | CMPW | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A1` | CMPW | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B1` | CMPW | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$8C` | CMPX | immediate | 3 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$9C` | CMPX | direct | 2 | 6 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$AC` | CMPX | indexed | 2+ | 6 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$BC` | CMPX | extended | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$8C` | CMPY | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$9C` | CMPY | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$AC` | CMPY | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$BC` | CMPY | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$43` | COMA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$53` | COMB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$43` | COMD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$43` | COME | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$53` | COMF | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$53` | COMW | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$03` | COM | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$63` | COM | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$73` | COM | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$3C` | CWAI | immediate | 2 | 22 | T | 20 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; emulation/native 22/20-cycle entry and frame checks |
| `$00/$19` | DAA | inherent | 1 | 2 | T | 1 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$4A` | DECA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$5A` | DECB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$4A` | DECD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$4A` | DECE | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$5A` | DECF | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$5A` | DECW | inherent | 2 | 3 | T | 2 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$0A` | DEC | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$6A` | DEC | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$7A` | DEC | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$8D` | DIVD | immediate | 3 | 25 | T | 25 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 128–255: -1 cycle, magnitude in B, N/V=1, C=quotient bit 0; hard overflow above 255: -13 cycles, absolute dividend in D, N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$11/$9D` | DIVD | direct | 3 | 27 | T | 26 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 128–255: -1 cycle, magnitude in B, N/V=1, C=quotient bit 0; hard overflow above 255: -13 cycles, absolute dividend in D, N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$11/$AD` | DIVD | indexed | 3+ | 27 | T | 27 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 128–255: -1 cycle, magnitude in B, N/V=1, C=quotient bit 0; hard overflow above 255: -13 cycles, absolute dividend in D, N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$11/$BD` | DIVD | extended | 4 | 28 | T | 27 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 128–255: -1 cycle, magnitude in B, N/V=1, C=quotient bit 0; hard overflow above 255: -13 cycles, absolute dividend in D, N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$11/$8E` | DIVQ | immediate | 4 | 34 | T | 34 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 32768–65535: no correction, magnitude in W,N=0,V=1,C=quotient bit 0; hard overflow above 65535: -21 cycles, absolute dividend in Q,N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$11/$9E` | DIVQ | direct | 3 | 36 | T | 35 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 32768–65535: no correction, magnitude in W,N=0,V=1,C=quotient bit 0; hard overflow above 65535: -21 cycles, absolute dividend in Q,N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$11/$AE` | DIVQ | indexed | 3+ | 36 | T | 36 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 32768–65535: no correction, magnitude in W,N=0,V=1,C=quotient bit 0; hard overflow above 65535: -21 cycles, absolute dividend in Q,N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$11/$BE` | DIVQ | extended | 4 | 37 | T | 36 | T | U | U | baseline; +1 E per negative dividend/divisor except divisor zero; soft overflow at quotient magnitude 32768–65535: no correction, magnitude in W,N=0,V=1,C=quotient bit 0; hard overflow above 65535: -21 cycles, absolute dividend in Q,N=dividend sign,V=1,Z/C=0 | instruction entry; printed p.149 note 12; original-device 6809Decoder measurements | signed and boundary matrices, zero-divisor phases asserted |
| `$00/$05` | EIM | direct | 3 | 6 | T | 6 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$65` | EIM | indexed | 3+ | 7 | T | 7 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$75` | EIM | extended | 4 | 7 | T | 7 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$88` | EORA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$98` | EORA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A8` | EORA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B8` | EORA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C8` | EORB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D8` | EORB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E8` | EORB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F8` | EORB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$88` | EORD | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$98` | EORD | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A8` | EORD | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B8` | EORD | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$36` | EORR | register_postbyte | 3 | 4 | T | 4 | T | P | P | — | 145-148 summary table | latest 479ca860 focused simunit; E,F and CC-target cases PASS |
| `$00/$1E` | r0,r1 | register_postbyte | 2 | 8 | T | 5 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$4C` | INCA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$5C` | INCB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$4C` | INCD | inherent | 2 | 3 | T | 2 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$4C` | INCE | inherent | 2 | 3 | T | 2 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$5C` | INCF | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$5C` | INCW | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$0C` | INC | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$6C` | INC | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$7C` | INC | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$0E` | JMP | direct | 2 | 3 | T | 2 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$6E` | JMP | indexed | 2+ | 3 | T | 3 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | latest 479ca860 focused simunit; indexed jump checked in both modes |
| `$00/$7E` | JMP | extended | 3 | 4 | T | 3 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$9D` | JSR | direct | 2 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$AD` | JSR | indexed | 2+ | 7 | T | 6 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | latest 479ca860 focused simunit; indexed call timing, stack, and return checked both modes |
| `$00/$BD` | JSR | extended | 3 | 8 | T | 7 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$86` | LDA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$96` | LDA | direct | 2 | 4 | T | 3 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$A6` | LDA | indexed | 2+ | 4 | T | 4 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$B6` | LDA | extended | 3 | 5 | T | 4 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$C6` | LDB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D6` | LDB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E6` | LDB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F6` | LDB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$CC` | LDD | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$DC` | LDD | direct | 2 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$EC` | LDD | indexed | 2+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$FC` | LDD | extended | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$86` | LDE | immediate | 3 | 3 | T | 3 | U | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$96` | LDE | direct | 3 | 5 | T | 4 | U | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$A6` | LDE | indexed | 3+ | 5 | U | 5 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$B6` | LDE | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$C6` | LDF | immediate | 3 | 3 | U | 3 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$D6` | LDF | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$E6` | LDF | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$F6` | LDF | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$3D` | LDMD | immediate | 3 | 5 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$CD` | LDQ | immediate | 5 | 5 | T | 5 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; immediate Q load checked in both modes |
| `$10/$DC` | LDQ | direct | 3 | 8 | U | 7 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$EC` | LDQ | indexed | 3+ | 8 | U | 8 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$FC` | LDQ | extended | 4 | 9 | U | 8 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$CE` | LDS | immediate | 4 | 4 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$DE` | LDS | direct | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$EE` | LDS | indexed | 3+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$FE` | LDS | extended | 4 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$CE` | LDU | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$DE` | LDU | direct | 2 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$EE` | LDU | indexed | 2+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$FE` | LDU | extended | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$86` | LDW | immediate | 4 | 4 | T | 4 | U | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$10/$96` | LDW | direct | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A6` | LDW | indexed | 3+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B6` | LDW | extended | 4 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$8E` | LDX | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$9E` | LDX | direct | 2 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$AE` | LDX | indexed | 2+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$BE` | LDX | extended | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$8E` | LDY | immediate | 4 | 4 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$9E` | LDY | direct | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$AE` | LDY | indexed | 3+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$BE` | LDY | extended | 4 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$36` | LDBT | immediate_postbyte | 4 | 7 | T | 6 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$32` | LEAS | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$33` | LEAU | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$30` | LEAX | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$31` | LEAY | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$48` | LSLA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$58` | LSLB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$48` | LSLD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$08` | LSL | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$68` | LSL | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$78` | LSL | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$44` | LSRA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$54` | LSRB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$04` | LSR | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$64` | LSR | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$74` | LSR | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$3D` | MUL | inherent | 1 | 11 | T | 10 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$8F` | MULD | immediate | 4 | 28 | T | 28 | T | P | P | baseline; +2 E if either or both operands are negative; updates N/Z and preserves V/C | instruction entry; printed p.149 note 6; original-device 6809Decoder measurements | signed matrix and V/C preservation asserted |
| `$11/$9F` | MULD | direct | 3 | 30 | T | 29 | T | P | P | baseline; +2 E if either or both operands are negative; updates N/Z and preserves V/C | instruction entry; printed p.149 note 6; original-device 6809Decoder measurements | signed matrix and V/C preservation asserted |
| `$11/$AF` | MULD | indexed | 3+ | 30 | T | 30 | T | P | P | baseline; +2 E if either or both operands are negative; updates N/Z and preserves V/C | instruction entry; printed p.149 note 6; original-device 6809Decoder measurements | signed matrix and V/C preservation asserted |
| `$11/$BF` | MULD | extended | 4 | 31 | T | 30 | T | P | P | baseline; +2 E if either or both operands are negative; updates N/Z and preserves V/C | instruction entry; printed p.149 note 6; original-device 6809Decoder measurements | signed matrix and V/C preservation asserted |
| `$00/$40` | NEGA | inherent | 1 | 2 | T | 1 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$50` | NEGB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$40` | NEGD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$00` | NEG | direct | 2 | 6 | T | 5 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$60` | NEG | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$70` | NEG | extended | 3 | 7 | T | 6 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$12` | NOP | inherent | 1 | 2 | T | 1 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$01` | OIM | direct | 3 | 6 | T | 6 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$61` | OIM | indexed | 3+ | 7 | T | 7 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$71` | OIM | extended | 4 | 7 | T | 7 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$8A` | ORA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$9A` | ORA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$AA` | ORA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$BA` | ORA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$CA` | ORB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$DA` | ORB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$EA` | ORB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$FA` | ORB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$1A` | ORCC | immediate | 2 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$8A` | ORD | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$9A` | ORD | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$AA` | ORD | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$BA` | ORD | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$35` | ORR | register_postbyte | 3 | 4 | T | 4 | T | P | P | — | 145-148 summary table | latest 479ca860 focused simunit; E,F and CC-target cases PASS |
| `$00/$34` | PSHS | register_mask_postbyte | 2 | 5 | T | 4 | T | U | U | baseline; add 1 cycle per byte selected by the stack-mask postbyte (Atkinson note 4) | 145-148 consolidated table; printed p.149 note 4 | hd6309_timing simunit; last reported PASS |
| `$00/$36` | PSHU | register_mask_postbyte | 2 | 5 | T | 4 | T | U | U | baseline; add 1 cycle per byte selected by the stack-mask postbyte (Atkinson note 4) | 145-148 consolidated table; printed p.149 note 4 | latest 479ca860 focused simunit; one-byte CC mask E/N 6/5 |
| `$10/$38` | PSHSW | register_mask_postbyte | 2 | 6 | T | 6 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; native W stack timing and byte order |
| `$10/$3A` | PSHUW | register_mask_postbyte | 2 | 6 | T | 6 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; native W stack timing and byte order |
| `$00/$35` | PULS | register_mask_postbyte | 2 | 5 | T | 4 | T | U | U | baseline; add 1 cycle per byte selected by the stack-mask postbyte (Atkinson note 4) | 145-148 consolidated table; printed p.149 note 4 | hd6309_timing simunit; last reported PASS |
| `$00/$37` | PULU | register_mask_postbyte | 2 | 5 | T | 4 | T | U | U | baseline; add 1 cycle per byte selected by the stack-mask postbyte (Atkinson note 4) | 145-148 consolidated table; printed p.149 note 4 | hd6309_timing simunit; last reported PASS |
| `$10/$39` | PULSW | register_mask_postbyte | 2 | 6 | T | 6 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; native W stack timing and byte order |
| `$10/$3B` | PULUW | register_mask_postbyte | 2 | 6 | T | 6 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; native W stack timing and byte order |
| `$00/$49` | ROLA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$59` | ROLB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$49` | ROLD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$59` | ROLW | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$09` | ROL | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$69` | ROL | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$79` | ROL | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$46` | RORA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$56` | RORB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$06` | ROR | direct | 2 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$66` | ROR | indexed | 2+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$76` | ROR | extended | 3 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$3B` | RTI (CC.E=1) | inherent | 1 | 15 | T | 17 | T | U | U | full frame restore; CC.E=1 | 145-148 summary table | latest 479ca860 focused simunit; seeded full-frame RTI measured 15/17 E in emulation/native modes |
| `$00/$3B` | RTI (CC.E=0) | inherent | 1 | 6 | T | 6 | T | U | U | short frame restore; CC.E=0 | 145-148 summary table | latest 479ca860 focused simunit; seeded emulation short-frame RTI measured 6 E |
| `$00/$39` | RTS | inherent | 1 | 5 | T | 4 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$82` | SBCA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$92` | SBCA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A2` | SBCA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B2` | SBCA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C2` | SBCB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D2` | SBCB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E2` | SBCB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F2` | SBCB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$82` | SBCD | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$92` | SBCD | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A2` | SBCD | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B2` | SBCD | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$33` | SBCR | register_postbyte | 3 | 4 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$1D` | SEX | inherent | 1 | 2 | T | 1 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$14` | SEXW | inherent | 1 | 4 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$97` | STA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A7` | STA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B7` | STA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D7` | STB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E7` | STB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F7` | STB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$DD` | STD | direct | 2 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$ED` | STD | indexed | 2+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$FD` | STD | extended | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$97` | STE | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$A7` | STE | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$B7` | STE | extended | 4 | 6 | T | 5 | U | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$11/$D7` | STF | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$E7` | STF | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$F7` | STF | extended | 4 | 6 | U | 5 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$10/$DD` | STQ | direct | 3 | 8 | U | 7 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$ED` | STQ | indexed | 3+ | 8 | U | 8 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$FD` | STQ | extended | 4 | 9 | U | 8 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$DF` | STS | direct | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$EF` | STS | indexed | 3+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$FF` | STS | extended | 4 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$DF` | STU | direct | 2 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$EF` | STU | indexed | 2+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$FF` | STU | extended | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$97` | STW | direct | 3 | 6 | T | 5 | U | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$10/$A7` | STW | indexed | 3+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B7` | STW | extended | 4 | 7 | U | 6 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$9F` | STX | direct | 2 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$AF` | STX | indexed | 2+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$BF` | STX | extended | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$9F` | STY | direct | 3 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$AF` | STY | indexed | 3+ | 6 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$BF` | STY | extended | 4 | 7 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$37` | STBT | immediate_postbyte | 4 | 8 | T | 7 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$80` | SUBA | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$90` | SUBA | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A0` | SUBA | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B0` | SUBA | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$C0` | SUBB | immediate | 2 | 2 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$D0` | SUBB | direct | 2 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$E0` | SUBB | indexed | 2+ | 4 | U | 4 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$F0` | SUBB | extended | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$83` | SUBD | immediate | 3 | 4 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$93` | SUBD | direct | 2 | 6 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$A3` | SUBD | indexed | 2+ | 6 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$B3` | SUBD | extended | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$80` | SUBE | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$90` | SUBE | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$A0` | SUBE | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$B0` | SUBE | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$C0` | SUBF | immediate | 3 | 3 | U | 3 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$D0` | SUBF | direct | 3 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$E0` | SUBF | indexed | 3+ | 5 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$11/$F0` | SUBF | extended | 4 | 6 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$32` | SUBR | register_postbyte | 3 | 4 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$80` | SUBW | immediate | 4 | 5 | U | 4 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$90` | SUBW | direct | 3 | 7 | U | 5 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$A0` | SUBW | indexed | 3+ | 7 | U | 6 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$10/$B0` | SUBW | extended | 4 | 8 | U | 6 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$3F` | SWI | inherent | 1 | 19 | T | 21 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; SWI measured 19/21 E in emulation/native modes with full-frame checks |
| `$10/$3F` | SWI2 | inherent | 2 | 20 | T | 22 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; SWI2 measured 20/22 E in emulation/native modes with full-frame checks |
| `$11/$3F` | SWI3 | inherent | 2 | 20 | T | 22 | T | U | U | — | 145-148 summary table | latest 479ca860 focused simunit; SWI3 measured 20/22 E in emulation/native modes with full-frame checks |
| `$00/$1F` | r0,r1 | register_postbyte | 2 | 6 | T | 4 | T | U | U | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$0B` | TIM | direct | 3 | 6 | T | 6 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$6B` | TIM | indexed | 3+ | 7 | T | 7 | T | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$7B` | TIM | extended | 4 | 7 | T | 7 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$4D` | TSTA | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$5D` | TSTB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$4D` | TSTD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$4D` | TSTE | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$11/$5D` | TSTF | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$10/$5D` | TSTW | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 summary table | not covered by current gate |
| `$00/$0D` | TST | direct | 2 | 6 | T | 4 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$6D` | TST | indexed | 2+ | 6 | U | 5 | U | P | P | indexed base; add indexed-postbyte increment when cycle token has + | 145-148 summary table | not covered by current gate |
| `$00/$7D` | TST | extended | 3 | 7 | T | 5 | T | P | P | — | 145-148 summary table | hd6309_timing simunit; last reported PASS |
| `$00/$57` | ASRB | inherent | 1 | 2 | U | 1 | U | P | P | — | 145-148 consolidated table (vertically wrapped unary rows) | not covered by current gate |
| `$10/$44` | LSRD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 consolidated table (vertically wrapped unary rows) | not covered by current gate |
| `$10/$46` | RORD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 consolidated table (vertically wrapped unary rows) | not covered by current gate |
| `$10/$47` | ASRD | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 consolidated table (vertically wrapped unary rows) | not covered by current gate |
| `$10/$54` | LSRW | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 consolidated table (vertically wrapped unary rows) | not covered by current gate |
| `$10/$56` | RORW | inherent | 2 | 3 | U | 2 | U | P | P | — | 145-148 consolidated table (vertically wrapped unary rows) | not covered by current gate |
| `$10/$21` | LBRN | relative | 4 | 5 | U | 5 | U | P | P | never taken | 149 relative table | not covered by current gate |
| `$00/$24` | BCC | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$25` | BCS | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$27` | BEQ | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$2C` | BGE | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$2E` | BGT | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$22` | BHI | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$24` | BHS | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$2F` | BLE | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$25` | BLO | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$23` | BLS | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$2D` | BLT | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$2B` | BMI | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$26` | BNE | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$2A` | BPL | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$20` | BRA | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$21` | BRN | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$8D` | BSR | relative | 2 | 7 | T | 6 | T | P | P | — | 149 relative addressing table | hd6309_timing simunit; last reported PASS |
| `$00/$28` | BVC | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$00/$29` | BVS | relative | 2 | 3 | U | 3 | U | P | P | — | 149 relative addressing table | not covered by current gate |
| `$10/$24` | LBCC | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$25` | LBCS | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$27` | LBEQ | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$2C` | LBGE | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$2E` | LBGT | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$22` | LBHI | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$24` | LBHS | relative | 4 | 5 | U | 5 | U | P | P | 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E | 149 relative table; note 11 | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$2F` | LBLE | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$25` | LBLO | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$23` | LBLS | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$2D` | LBLT | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$2B` | LBMI | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$26` | LBNE | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$2A` | LBPL | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$28` | LBVC | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$10/$29` | LBVS | relative | 4 | 5 | U | 5 | U | P | P | Atkinson p. 149: 5-E base; note 11 assigns the taken-only sixth cycle to the 6809, so HD6309 native taken remains 5 E; local MAME agrees | 149 relative table; note 11; corroborated by local MAME hd6309.lst | native taken timing sweep PASS: measured 5 E and target matched |
| `$00/$16` | LBRA | relative | 3 | 5 | T | 4 | T | P | P | — | 149 relative addressing table | hd6309_timing simunit; last reported PASS |
| `$00/$17` | LBSR | relative | 3 | 9 | T | 7 | T | P | P | — | 149 relative addressing table | hd6309_timing simunit; last reported PASS |
| `$00/$13` | SYNC | inherent | 1 | >=4 | T | >=3 | T | U | U | waits for interrupt; total depends on wait duration | 148 | latest 479ca860 focused simunit; emulation entry >=4 E and native entry >=3 E with IRQ wake |
| `$11/$38` | TFM r0+,r1+ | register_postbyte | 3 | 6+3n | T | 6+3n | T | U | U | n is the number of bytes transferred; register codes limited by note 10; same-register X+/X+ writes through the source's incremented address per original-device capture | 147-148; note 10 | hd6309_timing simunit; last reported PASS |
| `$11/$39` | TFM r0-,r1- | register_postbyte | 3 | 6+3n | T | 6+3n | T | U | U | n is the number of bytes transferred; register codes limited by note 10 | 147-148; note 10 | hd6309_timing simunit; last reported PASS |
| `$11/$3A` | TFM r0+,r1 | register_postbyte | 3 | 6+3n | T | 6+3n | T | U | U | n is the number of bytes transferred; register codes limited by note 10 | 147-148; note 10 | hd6309_timing simunit; last reported PASS |
| `$11/$3B` | TFM r0,r1+ | register_postbyte | 3 | 6+3n | T | 6+3n | T | U | U | n is the number of bytes transferred; register codes limited by note 10 | 147-148; note 10 | hd6309_timing simunit; last reported PASS |
| `$10/$50` | NEGW | inherent |  |  | U |  | U | U | U | MAME dispatches this opcode, but the cited Atkinson reference has no instruction/timing entry; direct hardware timing evidence is needed | unknown | not covered by current gate |
| `$10/$57` | ASRW | inherent |  |  | U |  | U | U | U | MAME dispatches this opcode, but the cited Atkinson reference has no instruction/timing entry; direct hardware timing evidence is needed | unknown | not covered by current gate |
| `$10/$58` | ASLW | inherent |  |  | U |  | U | U | U | MAME dispatches this opcode, but the cited Atkinson reference has no instruction/timing entry; direct hardware timing evidence is needed | unknown | not covered by current gate |
## Indexed postbyte detail

The instruction table reports an indexed base; the postbyte table below is a separate additive timing oracle. `T` is limited to postbytes explicitly exercised by the simunit. Sweep E/N records the cross-product of each documented postbyte and all fixed-count indexed opcode forms, using X as the variable base register and safe representative operands. The dynamic DIVD/DIVQ indexed forms are excluded from fixed-count comparison.

| Postbyte form | Pattern | E increment / bytes | N increment / bytes | Gate status | Sweep E | Sweep N | Evidence |
|---|---|---:|---:|---|---|
| ,R | `1rr00100` | 0 / 0 | 0 / 0 | T (sampled) | P | P | LDA indexed `,X` timing in hd6309_timing |
| [,R] | `1rr10100` | 3 / 0 | 3 / 0 | U | P | P | no matching indexed-postbyte case identified |
| n,R (-16..+15) | `0rrnnnnn` | 1 / 0 | 1 / 0 | U | P | P | no matching indexed-postbyte case identified |
| n,R (-128..+127) | `1rr01000` | 1 / 1 | 1 / 1 | U | P | P | no matching indexed-postbyte case identified |
| [n,R] | `1rr11000` | 4 / 1 | 4 / 1 | U | P | P | no matching indexed-postbyte case identified |
| n,R | `1rr01001` | 4 / 2 | 3 / 2 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| [n,R] | `1rr11001` | 7 / 2 | 6 / 2 | U | P | P | no matching indexed-postbyte case identified |
| ,W | `10001111` | 0 / 0 | 0 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| [,W] | `10010000` | 3 / 0 | 3 / 0 | U | P | P | no matching indexed-postbyte case identified |
| n,W | `10101111` | 2 / 2 | 2 / 2 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| [n,W] | `10110000` | 5 / 2 | 5 / 2 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| A,R | `1rr00110` | 1 / 0 | 1 / 0 | U | P | P | no matching indexed-postbyte case identified |
| B,R | `1rr00101` | 1 / 0 | 1 / 0 | U | P | P | no matching indexed-postbyte case identified |
| E,R | `1rr00111` | 1 / 0 | 1 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| F,R | `1rr01010` | 1 / 0 | 1 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| W,R | `1rr01110` | 1 / 0 | 1 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| D,R | `1rr01011` | 4 / 0 | 2 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| [A,R] | `1rr10110` | 4 / 0 | 4 / 0 | U | P | P | no matching indexed-postbyte case identified |
| [B,R] | `1rr10101` | 4 / 0 | 4 / 0 | U | P | P | no matching indexed-postbyte case identified |
| [E,R] | `1rr10111` | 4 / 0 | 4 / 0 | U | P | P | no matching indexed-postbyte case identified |
| [F,R] | `1rr11010` | 4 / 0 | 4 / 0 | U | P | P | no matching indexed-postbyte case identified |
| [W,R] | `1rr11110` | 4 / 0 | 4 / 0 | U | P | P | no matching indexed-postbyte case identified |
| [D,R] | `1rr11011` | 7 / 0 | 5 / 0 | U | P | P | no matching indexed-postbyte case identified |
| ,R+ | `1rr00000` | 2 / 0 | 1 / 0 | U | P | P | no matching indexed-postbyte case identified |
| ,R++ | `1rr00001` | 3 / 0 | 2 / 0 | U | P | P | no matching indexed-postbyte case identified |
| [,R++] | `1rr10001` | 6 / 0 | 5 / 0 | U | P | P | no matching indexed-postbyte case identified |
| ,-R | `1rr00010` | 2 / 0 | 1 / 0 | U | P | P | no matching indexed-postbyte case identified |
| ,--R | `1rr00011` | 3 / 0 | 2 / 0 | U | P | P | no matching indexed-postbyte case identified |
| [,--R] | `1rr10011` | 6 / 0 | 5 / 0 | U | P | P | no matching indexed-postbyte case identified |
| ,W++ | `11001111` | 1 / 0 | 1 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| [,W++] | `11010000` | 4 / 0 | 4 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| ,--W | `11101111` | 1 / 0 | 1 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| [,--W] | `11110000` | 4 / 0 | 4 / 0 | T (sampled) | P | P | LDA indexed timing cases in hd6309_timing |
| n,PCR | `1xx01100` | 1 / 1 | 1 / 1 | U | P | P | no matching indexed-postbyte case identified |
| [n,PCR] | `1xx11100` | 4 / 1 | 4 / 1 | U | P | P | no matching indexed-postbyte case identified |
| n,PCR | `1xx01101` | 5 / 2 | 3 / 2 | U | P | P | no matching indexed-postbyte case identified |
| [n,PCR] | `1xx11101` | 8 / 2 | 6 / 2 | U | P | P | no matching indexed-postbyte case identified |
| [n] | `10011111` | 5 / 2 | 4 / 2 | U | P | P | no matching indexed-postbyte case identified |

## Latest expanded sweep

This snapshot contains 7162 vectors: P=7162, X=0, U=0; 92 vectors excluded for specialized or unsupported setup.
CPU `mc6809i.v` SHA256 `cdb6ee04dadb51cf2d5b0d7f8ddbbb0d438b2f0d5c050b44e034c36b45c61187`; helper `jtframe_hd6309_arith.v` SHA256 `f4ea1859d64b0d6a64175d2b260ea07946ac0304c8d72105ab94a6eedeb9c9a1`; sweep testbench SHA256 `f5e6944d5ab1d8d3e41d030e23241a28d4b28410ff12a14552d3add2d1a9d1ba`; directed testbench SHA256 `55e37a3f07bf771e4b27ad837a7ff1d3f199544fb2e6dfdb28b86e8b70b7fce0`.
The vector and result CSV files are preserved with `--keep` for reproduction. The sweep checks timing and selected flow endpoints only; functional and bus evidence remains in the directed simunit.

## Remaining unverified coverage

The manifest has 900 opcode/form/mode cells. All native taken long conditional branches now match Atkinson’s 5-E baseline. **Six cells remain unresolved** because NEGW, ASRW, and ASLW in both modes have no published Atkinson timing value.

- **No published timing baseline — 6 unresolved cells:** NEGW `$10/$50`, ASRW `$10/$57`, and ASLW `$10/$58`, both modes. These legal MAME dispatches have no timing entry in Atkinson; MAME legality does not establish timing.

The generator reports **92 excluded row/mode entries** because they need special operands, control-flow/stack setup, or conditional timing. **86 of those entries have matching directed `T` evidence** in the focused simunit. The other six are exactly the legal dispatches without a published timing baseline. This exclusion count is different from the six unresolved timing cells: the branch vectors are exercised for flow and timing under the published p.149 rule.

The sweep passed all 7,162 vectors, including the 16 native taken long-conditional rows at 5 E with their expected flow endpoints. It covered all 38 indexed postbytes against each fixed-count indexed instruction/address row in both modes. DIVD/DIVQ indexed cases are excluded from fixed-count comparison because timing depends on operand and overflow conditions; directed tests cover the documented division cases. The 87 indexed inventory rows include those two dynamic divide rows.

## Reproduction and updates

Run the test from the repository root after sourcing the project environment:

```sh
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/hd6309_timing
```

The row inventory/timing snapshot was transcribed from the local `tasks/jtcores-147/artifacts/hd6309-instruction-timing.csv` and `hd6309-indexed-postbyte-timing.csv`; those artifacts are task-local and ignored by git. The legal decode source is the MAME table above. To regenerate those local inputs when available, run the task-local scripts `tasks/jtcores-147/scripts/build_hd6309_decode_manifest.py` and `tasks/jtcores-147/scripts/extract_hd6309_timing_matrix.py`. Update the `T/F/U` evidence only after checking the simunit program and its actual PASS log.
