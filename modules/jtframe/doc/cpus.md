# CPUs

Some CPUs are included in JTFRAME. Some of them can be found in other repositories in Github but the versions in JTFRAME include clock enable inputs and other improvements.

CPUs should have their respective license file in the folder, or directly embedded in the files. Note that they don't use GPL3 but more permissive licenses.

Many CPUs have convenient wrappers that add cycle recovery functionality, or
that allow the selection between different modules for the same CPU.

CPU selection is done via verilog [macros](macros.md).

Resource utilization based on MiST

Processor   | Logic Cells  |  BRAM |  Remarks
------------|--------------|-------|-----------------
M68000      |  5171        |    6  |  fx68k
i8751       |  4019        |    5  |  jtframe_8751mcu
M6809       |  2992        |    0  |  mc6809i
Konami CPU  |  2521        |    2  |  JTKCPU
Z80         |  2476        |    2  |  jtframe_sysz80 (T80s)
jt680x      |  1556        |    0  |  6801 variant (ucode synthesized as logic)
jt680x      |   516        |   19  |  6801 variant (ucode synthesized as BRAM)
6801_core.sv|  1039        |    0  |  3rd party 6801 core
6502        |   832        |    0  |  T65 (VHDL)
6502        |   937        |    0  |  chip_6502 (Andrew Holme)
PicoBlaze   |   950        |    0  |  PauloBlaze
MCS48       |   657        |    3  |  T48 (VHDL)

## M68000

fx68k is the preferred module. Because it designed in System Verilog, it cannot be simulated with Verilator. JTCORES points to a fork that contains a version manually converted to Verilog.

A [tool](https://github.com/ijor/fx68k/issues/16) capable of making the conversion from System Verilog to Verilog automatically appeared later. It has not been tested in JTCORES yet.

## Z80

The two basic modules to instantiate are:

- jtframe_sysz80_nvram
- jtframe_sysz80

These two modules offer a Z80 CPU plus:

- A connected RAM (or NVRAM)
- Automatic interrupt clear if CLR_INT parameter is set
- Automatic wait cycles inserted on M1 falling edge if M1_WAIT is set larger than zero

## 6502

There are two versions of the 6502 in JTFRAME:

- the T65, a re-implementation in VHDL
- the chip6502, a 1:1 translation of the original netlist by [Andrew Holme](http://www.aholme.co.uk/6502/Main.htm)

The netlist to verilog conversion requires a clock at least 16x faster than the target 6502 speed, and a 50% duty cycle for a PHI signal that represents the actual 6502 clock. The output has glitches similar to the original ones (not necessarily at the same time). Because of this, the connection is not straight forward. The wrapper [jtframe_mos6502](../hdl/cpu/jtframe_mos6502.v) takes care of these things. However, trying to use the ready signal so the CPU waits for memory data does not seem to operate reliably.

Because of the issue with the ready signal, the recommended CPU core is the T65 one. T65 also has a smaller footprint.

## VHDL

Verilator cannot simulate VHDL. It is possible to run mixed language simulations in _jtframe_ by using _modelsim_ in the simulation with `jtsim -modelsim`. However, this is very slow. In order to speed it up, convert the modules to verilog first using [ghdl](https://github.com/ghdl).

Note that `@` must go before the file name. As usual, file list order for VHDL is important.

```
ghdl -a -fsynopsys @gatherfile
ghdl synth --out=verilog toplevel_name > toplevel_name.v
```

To use `ghdl` in Ubuntu declare this function:

```
ghdl ()
{
    docker run -ti -w/mnt -v `pwd`:/mnt ghdl/ghdl:ubuntu22-llvm-11 ghdl $*
}
```

When converting VHDL to Verilog, it might be needed to rename instance names because they are used by the tool to generate signal names and that can create duplications in the verilog code. See [this issue](https://github.com/ghdl/ghdl/issues/2329).

Another valid tool is [VHD2VL](https://github.com/ldoolitt/vhd2vl)
