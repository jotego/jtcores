# SH7604 trace Verilator test

This simulation validates the SH7604 `TRACE_*` signals when the CPU is built with `VERILATOR_KEEP_CPU`.

The test program exercises literal loads, a register jump, ALU/register updates, memory load/store, compare/branch behavior, BSR/RTS delay slots, and a jump through the SH7604 cache data area. The C++ checker observes the committed trace stream through `TRACE_COMMIT_PC` and verifies that architectural register values match the assembly program expectations.

`TRACE_PC` is the live core PC for waveform and bus correlation. `TRACE_COMMIT_PC` is the PC paired with `TRACE_VALID` for committed-instruction checks.

The first checked case covers the CPS3 debug issue that motivated this test: after

```asm
mov.l lit_410, r13
mov.l lit_target, r14
jmp @r14
nop
```

`TRACE_R13` must become `0x00000410` at the commit point for the next instruction.

## Run

From this directory:

```sh
bash ./sim.sh
```

To keep an FST waveform:

```sh
bash ./sim.sh --keep
```

Extra arguments are forwarded to `test.cpp`:

```sh
bash ./sim.sh --trace-commits
bash ./sim.sh --timeout 200
```

## Requirements

Source the project environment first so `JTFRAME` is set:

```sh
source /home/jtejada/jtcores/setprj.sh
```

The script also requires GNU SuperH binutils. Override the defaults if needed:

```sh
AS_BIN=sh-elf-as OBJCOPY_BIN=sh-elf-objcopy bash ./sim.sh
```
