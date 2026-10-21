# Replacement Rastan history measurements

This task completes the remaining history experiments for Gitea
[jt51#7](http://gitea.jotego.es/jotego/jt51/issues/7),
[#8](http://gitea.jotego.es/jotego/jt51/issues/8) and
[#13](http://gitea.jotego.es/jotego/jt51/issues/13).
The physical/model comparisons and independent saved-output audits are complete.
See the [results](RESULTS.md), [coverage](plans/coverage.md),
[combined gap inventory](plans/gaps.md) and [archive guide](plans/archive.md).

The user authorized a newly recorded complete Rastan input. The original
98,880-write `rastan-ym2151.csv` from [#1](http://gitea.jotego.es/jotego/jt51/issues/1)
has not been recovered. [Replacement policy](plans/replacement-trace.md) keeps
these identities separate. Production JT51 remains `985a573` and the external
OPM reference remains `a0ab44`; no RTL change is part of these measurements.

The deterministic replacement is 30 seconds from reset, including coin/start,
right movement and repeated attack. Independently started MAME runs 06 and 07
have identical 418,412 address/data transactions, 209,206 register writes and
418 all-operator key-ons, exercising algorithms 0–5. Their complete public bus
CSV SHA256 is `252796f272f42a3efd1b0f7fe86fe31fe4d151511eefcd2dbef5eb8e9db11afd`;
the derived delta-time/register/value CSV is
`89d24478f38dbbf627e4a2828afdab144a1d693120666582f082cf15e140ceeb`.
The independent integer-time validator checks the 4 MHz lattice, address/data
pairs, every derived row, terminal counts and completion reason.
`bus.csv` is canonical: integer seconds/attoseconds plus both address and data
transactions. `registers.csv` is the compatible headerless
delta-seconds/register-decimal/value-decimal form; its first delta is zero.
The initial elapsed time is retained by the bus timestamps and `capture.txt`.
Full-prefix compilation uses the canonical bus, including that initial delay.

The selected natural algorithm-0 event follows all 107,500 preceding register
writes; its 1,200-write EVENT contains the channel-6 key-on at source row
107,532 and its channel-7 partner. The replay compiler retains every duplicate
write. Separate controlled probes append the retained original AR12/algorithm-0
and release-entry programs, and four literal raw-RR0/KS/KC combinations, after
that complete new prefix. These controlled probes are not natural trace events.
Matched conditioned runs and three independently initialized repetitions use
the same target bytecode with declared pretrigger counts 8192, 8199 and 8211.

The bench is the qualified Diet Go Go YM2151, 28-pin PicoROM resident monitor
and Chameleon96 direct serial capture through inverting adapters. User master
clock is 32.22 MHz/9, measured on pin at 3.57–3.58 MHz with 0.01 MHz tolerance.
LEFT is latch0, RIGHT latch1; both decode with inversion mask15.
No boot image, resident CPU firmware or FPGA image is replaced.

[Public interfaces and replay limits](plans/model-history.md) describe one-chip
model execution and the literal physical history. The 8 KiB monitor requires
chunks and recorded host pauses. Source intervals are mapped to source master
cycles using an 80-clock write allowance and approximately 37.5 clocks per CPU
delay count. Rounded delays, actual CPU/model overhead and host gaps define
expanded approximate timing. This is not continuous MAME timing, exact internal
acceptance phase, or a whole-song comparison. Native pitch is nominally scaled
by 3.58/4 relative to the 4 MHz source when an oscillator behaves identically;
the earlier qualified odd-MUL discrepancy remains a separate observation.

New mutable state, raw captures, source histories, failures, models and audit
proofs live only under this task. The previous campaign and its sealed archive
remain available through [the prior archive guide](../jtcores-143/plans/archive.md).
The new case is
`/gdrive/jotego/reverse/YM2151/2026-10-18-rastan-history-jt51-13/`.
It retains the complete replacement trace, all116 physical captures, all84
target model runs, separate controls, original failures, stimuli, plots and audits.
