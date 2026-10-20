# Timer measurements and production gap

Diet Go Go YM2151, 2026-10-17, production jt51 frozen at
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`.
No RTL or candidate patch was created. The user's earlier instruction in
[jt51 #3](http://gitea.jotego.es/jotego/jt51/issues/3) is to collect the measurement
gaps before addressing them together. This direct-serial bench is the new
jtcores #143 setup; the older X-Men acquisition instructions are not its wiring.

## Confirmed status-flag gap

All sixteen combinations of register 14 bits 0–3 were measured with fast timer
preloads, a long CPU delay, then status read before stopping/clearing. Each case
was initialized and repeated three times. All 48 observations match the Yamaha
application notes and the independent OPM model. Production jt51 disagrees in
seven control combinations:

| Reg 14 | Physical status, all 3 repeats | OPM status | jt51 status |
|---|---:|---:|---:|
| 00 | 0 | 0 | 0 |
| 01 | 0 | 0 | 1 |
| 02 | 0 | 0 | 2 |
| 03 | 0 | 0 | 3 |
| 04 | 0 | 0 | 0 |
| 05 | 1 | 1 | 1 |
| 06 | 0 | 0 | 2 |
| 07 | 1 | 1 | 3 |
| 08 | 0 | 0 | 0 |
| 09 | 0 | 0 | 1 |
| 0A | 2 | 2 | 2 |
| 0B | 2 | 2 | 3 |
| 0C | 0 | 0 | 0 |
| 0D | 1 | 1 | 1 |
| 0E | 2 | 2 | 2 |
| 0F | 3 | 3 | 3 |

Bits 0/1 load the timers; bits 2/3 enable their overflow flag registers. With
IRQEN clear, an overflow must not create a new status flag. Existing jt51 records
it anyway, while separately masking the IRQ output. This status mismatch is
observable directly through the CPU bus and is independent of audio decoding
and of the unresolved phase/multiplier observation.

Two seven-step physical sequences additionally confirm, for both timers:
disabled overflow stays clear; enabling allows a new flag; disabling after a
latched flag retains it; explicit clear while disabled keeps it clear; reenabling
allows a new flag; stopping preserves the flag; clearing while stopped clears it.
The monitor completed every program without dropped reply bytes or reset.

Primary source: `modules/jt51/doc/yamaha/ym2151_app_notes.pdf`, printed pages
12–13 (PDF pages 13–14), describes IRQEN as inhibiting the flag register, LOAD
as start/stop, and F RESET as explicit flag clear. The independent OPM API and
MAME ymfm source reviews are summarized in [the timer probe](../ver/timer_flags/README.md).

## IRQ qualification limit and standalone regression

The physical IRQ pin was not captured. Both independent models retain IRQ
after an enabled overflow until explicit clear, even if IRQEN is later disabled.
Production jt51 withdraws IRQ immediately when IRQEN clears. This associated
IRQ behavior is supported by source/documentation review, not a physical IRQ
measurement on this bench.

The standalone public-port timer probe currently reports **eight assertion
failures**, covering disabled-overflow flags, exposing old overflow when enabling,
and lost IRQ after disabling an existing flag. The eight assertions are not the
same count as the seven full-chip control combinations above. The probe also
passes its period/reload, stopped-counter, clear-priority, independent-flag,
CEN/ZERO pause and CSM-overflow-availability checks.

```
source setprj.sh
bash tasks/jtcores-143/ver/timer_flags/sim.sh
```

Its exit status **1 is expected against the frozen production revision** and
indicates conformance gaps. Logs and waveforms are retained in a fresh directory.
It has no `.simunit` marker and is not registered as a passing CI regression.
No production edit or implementation proposal follows from this measurement.

## Timer period bounds

An exploratory binary search used 220 physical programs across these preloads:

| Timer | Preloads | Nominal periods at 3.58 MHz |
|---|---|---|
| A | 0, 256, 512, 768, 900 | 18.3061, 13.7296, 9.1531, 4.5765, 2.2168 ms |
| B | 0, 64, 128, 192, 224 | 73.2246, 54.9184, 36.6123, 18.3061, 9.1531 ms |

Near-boundary repeated reads vary. A single binary-search transition therefore
does not establish an exact timer period. Timer A's master/64 phase and Timer B's
additional free-running divide-by-16 prescaler leave first-interval uncertainty.
No timer timing change is proposed from these observations.

The actual assembled HuC6280 monitor was executed in MAME with YM bus taps.
For loop count `N`, the elapsed start-register data write to status read is:

```
elapsed_master_clocks = (28*N + 4*floor(N/256)) * 4/3 + 246.6666666667
```

Twenty independently recorded tap intervals confirm this expression. It uses
the board's nominal effective CPU clock 2.685 MHz and YM clock 3.58 MHz; the
4/3 ratio is from the common oscillator and MAME's Diet Go Go configuration.
This calibrates the CPU program in the model, not a physical bus timestamp.
The existing jt51/OPM bytecode harnesses' approximate delay loop is not used to
claim exact event equivalence for these boundary programs.

Guarded clear/overflow points allow the start-phase uncertainty explicitly:
clear points are at least 128 master clocks before Timer A's nominal period or
1100 before Timer B's; overflow points are at least 200 clocks after the nominal
period. All twenty guarded points passed five independent initializations,
**100/100 physical observations**. This supports the expected coarse periods
and CPU/chip clock relationship; it does not establish cycle-accurate first
overflow timing. Native RTL probe periods are checked separately in ZERO ticks
(64 master clocks, with Timer B divided by 16).

## Reproduction and evidence

```
go run tasks/jtcores-143/host/timer_programs.go -output NEW_DIRECTORY
```

The generator creates sixteen flag-control programs and twenty guarded period
programs, with expected statuses and SHA256 in its manifest. Apply a program
using `monitor.py run --program FILE --until-reply`. Use three independent
initializations for flag controls and five for guarded periods. The generated
programs match the executed measurement bytes exactly. End every case by
stopping/clearing both timers after the status read; the monitor retains the
read status for its completion reply.

Local evidence, excluded from git:

- `artifacts/timer-full-controls`: 48 physical replies and full-chip jt51/OPM
  outputs for all sixteen control combinations.
- `artifacts/timer-controls`: initial minimal discrepancy and fourteen sticky
  state-sequence observations.
- `artifacts/timer-boundaries`: exploratory search, MAME bus timing/reference,
  and `guards/` with all 100 accepted observations.
- `artifacts/timer-flags-probe`: unique standalone baseline regression runs.
- `artifacts/timer-flag-fix`: primary-source OCR and frozen baseline metadata;
  despite the historical directory name, no fix or patch exists there.

Still outstanding: physical IRQ, exact event phase, mid-run reload boundaries,
CSM audio/key-on behavior and interactions with envelope and manual key control.
