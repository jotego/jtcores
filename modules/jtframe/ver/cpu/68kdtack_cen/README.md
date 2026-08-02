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
- effective phase balance after excluding delayed enables;
- cumulative effective CPU time against the no-wait reference.

After the traffic ends, 10,000 master-clock cycles are allowed for recovery.
This is much longer than required to drain the maximum visible 11-bit debt.
The current implementation wraps that counter once and permanently loses 1,024
CPU cycles, producing this intentional red-regression result for issue #94:

```text
raw       = 13884 / 13885
effective =  9497 /  9497
reference = 10521 / 10521
```

The raw and effective phase pairs remain balanced within one, but the elapsed
CPU time is not recovered. The test must become green when the recovery logic
is corrected.

## Running

From the repository root:

```bash
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_cen
```
