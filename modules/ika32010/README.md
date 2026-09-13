# IKA32010 module

This directory contains the synthesizable SystemVerilog sources from
[ika-musume/IKA32010](https://github.com/ika-musume/IKA32010), a TMS320C10
(TMS32010) core by Sehyeon Kim (Raki), imported from commit
`51bc1f05a2a08a61c8815a9643d08a42e99779c6`. The original license is preserved
in [LICENSE](LICENSE), and the original README is copied to
[doc/README.md](doc/README.md).

`IKA32010.sv` includes `IKA32010_mnemonics.sv` and `IKA32010_disasm.sv` with
`` `include ``, so only `IKA32010.sv` is listed in `cfg/files.yaml`. Quartus
finds the includes next to the including file; simulators need this directory
on their include path, which `jtsim` provides.

## Local changes

`IKA32010_mnemonics.sv` and `IKA32010_disasm.sv` are unmodified. `IKA32010.sv`
differs from upstream in two places:

- Three `verilator lint_off` pragmas (`WIDTHEXPAND`, `COMBDLY`, `MULTIDRIVEN`)
  are prepended, so the file passes the lint gates of the jtframe unit tests
  and of `jtcore`. `MULTIDRIVEN` is raised by `IKA32010_ram`, whose `initial`
  block zeroes the RAM with non-blocking assignments beside its clocked write.
- `` `define IKA32010_DISASSEMBLY `` is commented out. Upstream defines it
  unconditionally, which makes every build include the disassembler. Quartus
  25.1 rejects that file (a bit-select of a concatenation, and `string`
  variables declared outside a function), and so does Icarus Verilog. Define
  `IKA32010_DISASSEMBLY` on the command line of a Verilator simulation to get
  the disassembly log back.

## Known issue

The data memory page pointer is cleared while the core is *out* of reset:
`IKA32010.sv` reads `if(i_RS_n) reg_dp <= 1'b0;` where `!i_RS_n` is meant, so
`LDPK 1` and `LDP` have no effect and RAM page 1 (0x80-0x8f) cannot be reached
by direct addressing. A program that stores 0x55 on page 1 and reads it back
ends with ACC = 0 here and ACC = 0x55 in MAME. The Wardner DSP program never
selects page 1 - no `LDPK 1`, `LDP` or `LST` word appears anywhere in its ROM -
so the line is left as upstream has it.

## Tests

`ver/lint` elaborates the core, resets it and checks that it fetches a ROM of
zeros sequentially. The core is exercised in circuit by the Wardner DSP benches
in `cores/wardner/ver/dsp`, which compare it against a C transcription of MAME.
