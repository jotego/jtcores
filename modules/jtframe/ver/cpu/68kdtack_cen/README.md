# 68000 DTACK and clock-enable test

This simunit verifies the nominal 8, 9, 10, 12, and 16 MHz enable ratios of
`jtframe_68kdtack_cen` and its recovery from memory wait states.

## Recovery regression

The recovery test configures the DUT and a no-wait reference instance for a
10 MHz 68000 clock. It applies 3,000 deterministic SDRAM-style transactions to
the DUT, with six to ten busy master-clock cycles followed by a two-to-five
cycle inter-transaction gap.

The test measures:

- raw `cpu_cen` and `cpu_cenb` phase balance;
- the peak recovery debt;
- aggregate effective CPU time against the no-wait reference.

The recovery regression uses a dedicated DUT so its traffic and accumulated
debt cannot affect the legacy `fave` checks. After the traffic ends, 10,000
master-clock cycles are allowed for recovery. This is much longer than required
to drain the counter.

When recovery was restricted to `ASn`, this workload wrapped the 11-bit counter
once and permanently lost 1,024 CPU cycles. Allowing recovery after `DTACKn`
is asserted reduces the peak debt to 829, so the original counter width is
sufficient and the regression completes with no lost effective CPU time:

```text
raw       = 14908 / 14909
effective = 10518 / 10524
reference = 10521 / 10521
peak debt = 829
```

The raw phase pair must remain balanced within one, while the aggregate effective
count must match the aggregate reference count. In simulation, the module
reports a failure and stops immediately if recovery debt reaches the maximum
counter value and another delayed CPU enable would wrap it.

## Running

From the repository root:

```bash
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_cen
```
