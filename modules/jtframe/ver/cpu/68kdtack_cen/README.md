# 68000 DTACK and clock enables

This simunit checks the production `jtframe_68kdtack_cen` divider at 8, 9, 10,
12, and 16 MHz, delivered phase accounting, configured waits, and bus ownership.
The [cached SDRAM integration regression](../68kdtack_cache/README.md) separately
checks real fx68k instruction timing through ROM/RAM requesters, the SDRAM
controller, and the memory model. Both levels of verification are necessary.

## Actual phase recovery

The module allows request setup to complete, then holds the Phi2 that samples
DTACK when memory is late. Both CPU enables remain low during this hold. The
next phase is preserved, and only scheduled phases actually withheld are added
to recovery debt. Extra delivered phases repay that debt after memory is ready.
Frequency reporting counts delivered Phi1 events directly.

The recovery test uses a 10 MHz DUT and an independently running no-wait
reference divider. It generates 3,000 deterministic transactions from actual
CPU phase events: request setup follows Phi1, DTACK is sampled on Phi2, and
bus release follows Phi1. Response latency varies from six to twenty-two master
clocks. Four Phi1 events of internal execution between transactions leave enough
recovery capacity for this offered memory workload.

It checks the exact ledger:

```text
delivered phases = nominal scheduled phases - withheld phases + replayed phases
```

After traffic and 10,000 master clocks for recovery, debt must be zero,
withheld and replayed counts must match, and delivered phases must equal the
no-wait reference. Phi1 and Phi2 must never overlap, must alternate across holds
and recovery, and their final counts may differ by at most one. The reported
frequency must remain within the 10 MHz tolerance.

There is no separate fictitious effective-phase stream. Counting delivered
phases as lost while allowing the CPU to keep executing was the old failure
mode; this test checks physical enable outputs against the ledger.

## Legitimate waits and bus ownership

A long artificial memory stall first accumulates debt. With that debt pending,
the test asserts `bus_legit`, then `bus_ack`, and checks that:

- both withholding and replay are disabled;
- nominal CPU phases continue, allowing board wait counters and arbitration to
  progress;
- debt neither increases nor decreases while either exclusion applies;
- debt drains after the exclusions end.

## WAIT1 and extra wait qualification

Six phase-driven instances cover `WAIT1=0/1`, each with no extra wait, `wait2`,
or `wait3`. With memory immediately ready, the acknowledgement qualification
occurs after these delivered Phi1 events following request assertion:

| WAIT1 | No extra wait | wait2 | wait3 |
|---|---:|---:|---:|
| 0 | 0 | 1 | 2 |
| 1 | 2 | 2 | 3 |

These are qualification-event counts, not claims about complete 68000
instruction cycles. The test also preserves the original synchronized check
that `wait3` acknowledges later than `wait2`.

Each configuration then receives a late memory response. Both CPU enables must
be held, debt must accrue, and DTACK must become ready on master-clock edges
without requiring a held Phi1 to execute. A following transfer begins with debt
still pending: configured board waits must not charge or spend it. Debt must
then drain in idle even if the wait inputs retain the preceding selection.

## Running

From the repository root:

```bash
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_cen
```
