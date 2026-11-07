# IKA32010

TMS320C10 core by Sehyeon Kim (Raki), copied from
https://github.com/ika-musume/IKA32010 at commit 51bc1f05a2a0. BSD 2-Clause,
see LICENSE. Use it through `jtframe_tms32010` (`cfg/cpu/jtframe_tms32010.yaml`).

Local changes to `IKA32010.sv`:

- `verilator lint_off` for WIDTHEXPAND, COMBDLY and MULTIDRIVEN at the top.
- `` `define IKA32010_DISASSEMBLY `` commented out. Upstream always defines it,
  and Quartus rejects `IKA32010_disasm.sv`.
- `CALL` pushes the address after its operand. Upstream pushes the operand's
  address, so `RET` returns one word early. Marked `jtcores:`.

Not changed:

- DP is cleared while the core runs (`if(i_RS_n)`), so direct addressing
  cannot reach RAM page 1.
- INTM is not set when an interrupt is taken, only by `DINT`.
