# IKAOPM
YM2151 Verilog core for FPGA implementation. It was reverse-engineered with only Yamaha's datasheet and the [die shot](https://siliconpr0n.org/archive/doku.php?id=mcmaster:yamaha:ym2151) from siliconpr0n. **This core does not reference any existing hard/soft core.** © 2023 Sehyeon Kim(Raki)

<p align=center><img alt="header image" src="./docs/ikamusume_dx7.jpg" height="auto" width="640"></p>

Copyrighted work. Permitted to be used as the header image. Painted by [SEONGSU](https://twitter.com/seongsu_twit).

## Features
* A **cycle-accurate, die shot based, BSD2 licensed** core.
* FPGA proven. Special thanks go to [@kunichiko]( https://github.com/kunichiko ) and [@jburks]( https://github.com/jburks ).
* Accurately emulates most signals of the actual chip.
* Emulates uneven mixing behavior of the actual chip's accumulator.
* All LSI test bits are implemented.

## Module instantiation
The steps below show how to instantiate the IKAOPM module in Verilog:

1. Download this repository or add it as a submodule to your project.
2. You can use the Verilog snippet below to instantiate the module.

```verilog
//Verilog module instantiation example
IKAOPM #(
    .FULLY_SYNCHRONOUS          (1                          ),
    .FAST_RESET                 (0                          ),
    .USE_BRAM                   (0                          )
) u_ikaopm_0 (
    .i_EMUCLK                   (                           ),

    .i_phiM_PCEN_n              (                           ),
    //.i_phi1_PCEN_n              (                           ), //compilation option
    //.i_phi1_NCEN_n              (                           ),

    .i_IC_n                     (                           ),

    .o_phi1                     (                           ),

    //.o_EMU_BUSY_FLAG            (                           ), //compilation option
    .i_CS_n                     (                           ),
    .i_RD_n                     (                           ),
    .i_WR_n                     (                           ),
    .i_A0                       (                           ),

    .i_D                        (                           ),
    .o_D                        (                           ),
    .o_D_OE                     (                           ),

    .o_CT1                      (                           ),
    .o_CT2                      (                           ),

    .o_IRQ_n                    (                           ),

    .o_SH1                      (                           ),
    .o_SH2                      (                           ),

    .o_SO                       (                           ),

    .o_EMU_R_SAMPLE             (                           ),
    .o_EMU_R_EX                 (                           ),
    .o_EMU_R                    (                           ),

    .o_EMU_L_SAMPLE             (                           ),
    .o_EMU_L_EX                 (                           ),
    .o_EMU_L                    (                           )
);
```
3. Attach your signals to the port. The direction and the polarity of the signals are described in the port names. The section below explains what the signals mean.


* `FULLY_SYNCHRONOUS` **1** makes the entire module synchronized(default, recommended). A 2-stage synchronizer is added to all asynchronous control signal inputs. Hence, `i_EMUCLK` at 3.58 MHz, all write operations are delayed by 2 clocks. If **0**, 10 latches are used. There are two unsafe D-latches to emulate an SR-latch for a write request, and an 8-bit D-latch to temporarily store a data bus write value. When using the latches, you must ensure that the enable signals are given the appropriate clock or global attribute. Quartus displays several warnings and treats these signals as GCLK. Because the latch enable signals are considered clocks, the timing analyzer will complain that additional constraints should be added to the bus control signals. I have verified that these asynchronous circuits work on an actual chip, but timing issues may exist.
* `FAST_RESET` When set to **0**, assertion of the `i_IC_n` for at least 64 cycles of phiM **should be guaranteed during the operation of `i_EMUCLK` and `i_phiM_PCEN_n`** to ensure reset of all pipelines in the IKAOPM. If it is **1**, then if `i_IC_n` is logic low, it forces phi1_cen, the internal divided clock enable, to be enabled so that the pipelines reset at the same rate as the `i_EMUCLK`. Therefore, `i_phiM_PCEN_n` does not need to operate at this time. 
* `USE_BRAM` When set to **1**, shift registers are implemented by block RAMs, reducing the usage of general logic cells (LUT + flip-flop). Default is **0** - use the general logic to implement shift registers.
* `i_EMUCLK` is your system clock.
* `i_phiM_PCEN_n` is the clock enable(negative logic) for positive edge of the phiM.
* `i_IC_n` is the synchronous reset. To flush every pipelines in the module, IC_n must be kept at zero for at least 64 phiM cycles. Note that while the `i_IC_n` is asserted, the `i_phiM_PCEN_n` must be operating.
* `o_D_OE` is the output enable for FPGA's tri-state I/O driver.
* `o_SO` is the YM3012-type serial lossy audio output.
* `o_EMU_R_SAMPLE` and `o_EMU_L_SAMPLE` are external latch enable strobes. You can adjust pulse width by altering the parameter `SAMPLE_STROBE_LENGTH` in IKAOPM_acc.v. Because the YM2151 does not update samples simultaneously, there is the corresponding strobe for each of the two channels. Therefore, if you are configuring a system that requires both channels to be updated together, you can use only one channel's strobe. This is because the other channel's value will not be changed while one is being updated.
* `o_EMU_R_EX` and `o_EMU_L_EX` are the 16-bit signed full-range audio outputs. Not recommended.
* `o_EMU_R` and `o_EMU_L` are the 16-bit signed lossy audio outputs. Recommended.


## CT2 and CT1 port description
Pin number 8 and 9 of the YM2151 are used as GPO ports. They are referred to as CT2 and CT1 respectively, but unfortunately Yamaha doesn't seem to have taken the naming of them seriously. There are datasheets that have CT2 and CT1 reversed in order. Looking at the die shot, bit 7 of the 0x1B register is connected to the pin 8, and bit 6 is connected to the pin 9. I assume that in this core, **bit 7 of the 0x1B register = CT2 = pin 8, bit 6 of the same register = CT1 = pin 9**. In addition, **the pin that the internal data `lfo_clk` flows out of when test mode is turned on is CT1 = pin 9**.

## Compilation options
* `IKAOPM_DEBUG` You can view the values inside like a static storage.
* `IKAOPM_BUSY_FLAG_ENABLE` A busy flag for an asynchronous FIFO that performs delayed write for a faster CPU bus. This signal is equal to `o_D[7]`.
* `IKAOPM_USER_DEFINED_CLOCK_ENABLES` For efficiency in clocking, you can provide the clock enables used by IKAOPM from outside of the module. Read the comments in the IKAOPM.v for recommended timings.

## FPGA resource usage
* Altera EP4CE6E22C8: 2231 LEs, 1330 registers, BRAM 6608 bits, fmax=73.83MHz(slow 85C)
* Altera 5CSEBA6U23I7(MiSTer): 851 ALMs, 1490 registers, BRAM 2952 bits, 1 DSP block, fmax=143.64MHz(slow 100C)
* Xilinx XC7Z020CLG400(Zynq7020): 1174 LUTs, 116 LUTRAMs, 1579 registers, BRAM 2.5 blocks(8192 bits)
* Lattice ICE40UP5K-SG48: with USE_BRAM=1: 4516 LC (85%), 10 RAM blocks.
