# MC6802 completion

The MC6802 profile uses the shared jt680x engine, YAML bus sequences and an
E/VMA/MR wrapper. Opcode regressions, basic IRQ/NMI, WAI/HALT and Seicro boot
checks pass. Full conformance to the [Motorola manual](https://www.retrodocs.fr/wp-content/uploads/pdf/TexasInstrument-MC6802.pdf)
remains pending.

## Remaining work

- Independently verify documented opcodes, flags and cycle-by-cycle bus behavior,
  including CPX, dummy accesses and MR stretching limits.
- Cover interrupt, WAI, HALT and reset edge cases, especially short IRQ/NMI pulses
  during stalls, masking boundaries and simultaneous requests.
- Add a generic chip wrapper for 128-byte RAM, RE, first-32-byte standby retention
  and explicit data-bus ownership.
- Resolve BRN/direct-JSR eligibility and the manual's WAI stack-cycle ambiguity.
  Keep NSC8105 extensions and undocumented FC compatibility separate from MC6802
  conformance claims.
- Preserve 6801/6301 regressions and validate on hardware before declaring complete.

## Checks

From the repository root:

```sh
modules/jt680x/ver/6802/sim.sh
```
