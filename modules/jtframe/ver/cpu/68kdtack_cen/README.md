# 68000 DTACK and clock-enable test

This simunit verifies the nominal 8, 9, 10, 12, and 16 MHz enable ratios of
`jtframe_68kdtack_cen` and its recovery from memory wait states.

## Recovery regression

The recovery test configures the DUT and a no-wait reference instance for a
10 MHz 68000 clock. It applies 3,000 deterministic SDRAM-style transactions to
the DUT, with six to ten busy master-clock cycles followed by a two-to-five
cycle inter-transaction gap.

While an implementation-only SDRAM delay is active, each nominal phase selected
by the fractional clock divider is added to the recovery counter. The phase
enables continue to clock fx68k normally while it observes `DTACKn`; the charged
phases are replayed after the bus is ready.

The divider's current `over` event must be used for this accounting.
`cpu_cen` and `cpu_cenb` are registered outputs, so sampling them in the same
clocked block refers to the preceding edge. If `delayed` changes around an SDRAM
response, that misaligns the phase ledger and replays phases that were not
scheduled while the delay was active.

Frequency reporting uses the same aligned events. A scheduled phase contributes
when it is not charged as delayed, and its eventual recovery phase contributes
when it is replayed. A dedicated parity bit pairs this effective half-phase
stream into reported CPU cycles. The raw `risefall` polarity cannot be reused,
because a charged phase and its later replay may occupy different positions in
the raw output stream. The input to `fave` must also not use
`cpu_cen && !delayed`, because that combines the preceding registered phase with
the current delay state and under-reports the effective frequency.

The test measures:

- raw `cpu_cen` and `cpu_cenb` phase balance;
- scheduled recovery debt against the number of replayed phases;
- delivered phases against the no-wait schedule plus the replayed phases;
- the peak recovery debt;
- aligned effective-phase counts and the reported effective frequency.

The recovery regression uses a dedicated DUT so its traffic and accumulated
debt cannot affect the legacy `fave` checks. After the traffic ends, 10,000
master-clock cycles are allowed for recovery. This is much longer than required
to drain the counter.

When recovery was restricted to `ASn`, this workload wrapped the 11-bit counter
once and permanently lost 1,024 CPU cycles. Allowing recovery after `DTACKn`
is asserted reduces the peak debt to 754, so the original counter width is
sufficient and the regression completes with no lost recovery phases:

```text
raw         = 14871 / 14871
effective   = 10521 / 10521
reference   = 10521 / 10521
debt/replay = 8700 / 8700
peak debt   = 754
fave        = 0999 or 1000
```

The phase pair must remain balanced within one. Scheduled debt must be replayed
exactly, and the total delivered phase count must equal the no-wait schedule plus
those replayed phases. In simulation, the module reports a failure and stops
immediately if recovery debt reaches the maximum counter value and another
scheduled delayed phase would wrap it.

## Wait-state latency regression

Two synchronized instances run at a 12 MHz CPU enable rate. One requests
`wait2`, while the other requests `wait3`. The test measures master-clock cycles
from the same falling `ASn` edge to each falling `DTACKn` edge and asserts that
`wait3` takes longer than `wait2`.

## Running

From the repository root:

```bash
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_cen
```
