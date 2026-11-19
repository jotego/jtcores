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

## Wait-state qualification

`waitn` is the number of 68000 wait states (whole CPU clocks) for the transfer.
Eight phase-driven instances cover `waitn=0..3`, each with the input held
constant or driven only while AS is low, like a wait taken from an AS-gated
chip select. With memory immediately ready, the acknowledgement qualification
occurs after these delivered Phi1 events following request assertion:

| waitn | 0 | 1 | 2 | 3 |
|---|---:|---:|---:|---:|
| Phi1 events | 0 | 2 | 3 | 4 |

The Phi1 entering S4 precedes the first DTACK sample, so `N` wait states need
`N+1` events. Gated and constant inputs must give the same count. The test
also checks that `waitn=2` acknowledges later than `waitn=1`.

Each configuration then receives a late memory response. Both CPU enables must
be held, debt must accrue, and DTACK must become ready on master-clock edges
without requiring a held Phi1 to execute. A following transfer begins with debt
still pending: configured board waits must not charge or spend it. Debt must
then drain in idle.

## Running

From the repository root:

```bash
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_cen
```
