# IKA32010
A BSD-licensed core for TI's TMS32010 DSP © 2024 Sehyeon Kim(Raki)

## Features
* A **semi-cycle-accurate, BSD2 licensed** core.
* FPGA proven.

## Current status
v1.0 – ✅Verified using the arcade games Twin Cobra, Sky Shark, and Wardner by atrac17.

## Module instantiation
The steps below show how to instantiate the IKA32010 module in Verilog:

1. Download this repository or add it as a submodule to your project.
2. You can use the Verilog snippet below to instantiate the module.

```verilog
//Verilog module instantiation example
IKA32010 u_main (
    .i_EMUCLK               (                           ),
    .i_CLKIN_PCEN           (                           ),

    .o_CLKOUT               (                           ),
    .o_CLKOUT_PCEN          (                           ),
    .o_CLKOUT_NCEN          (                           ),

    .i_RS_n                 (                           ),

    .o_MEN_n                (                           ),
    .o_DEN_n                (                           ),
    .o_WE_n                 (                           ),

    .o_AOUT                 (                           ),
    .i_DIN                  (                           ),
    .o_DOUT                 (                           ),
    .o_DOUT_OE              (                           ),

    .i_BIO_n                (                           ),
    .i_INT_n                (                           )
);
```
3. Attach your signals to the port. The direction and the polarity of the signals are described in the port names. The section below explains what the signals mean.


* `i_EMUCLK` is your system clock.
* `i_CLKIN_PCEN` is the clock enable(positive logic) for positive edge of the CLKIN.
* `o_CLKOUT` is the divided clock from the DSP.
* `i_RS_n` is the synchronous reset.
* `o_DOUT_OE` is the output enable for FPGA's tri-state I/O driver.
* The other signals have the same function as the pins on the original chip.

## Compilation options
* `IKA32010_DISASSEMBLY` You can track the disassembly log to see what opcodes the DSP executed. This requires the `IKA32010_disasm.sv` file.
* `IKA32010_DISASSEMBLY_SHOWID` displays the device ID in a console. This is useful when debugging a system with multiple DSPs or a system with another CPU.
* `IKA32010_DEVICE_ID` and the following string will name the device.

## FPGA resource usage
* Altera EP4CE6E22C8: 1243 LEs, 275 registers, BRAM 4096 bits, two 9-bit multiplier elements, fmax=44.98MHz(slow 85C), fmax=103.95MHz(fast 0C)
* Altera 5CSEBA6U23I7(MiSTer): 601 ALMs, 275 registers, BRAM 4096 bits, 1 DSP block, fmax=60.28MHz(slow 100C), fmax=132.33MHz(fast -40C)
