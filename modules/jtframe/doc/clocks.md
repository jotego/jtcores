# Game clocks

Games are expected to operate on a 48MHz clock using clock enable signals. There is an optional 24MHz clock for modules that cannot be synthesized at 48MHz.

 clock input | Macro Needed
-------------|--------------
clk96        | Always present
clk24        | Always present
clk          | 48MHz unless JTFRAME_SDRAM96 is defined, then 96MHz
clk48        | JTFRAME_CLK48

Note that although clk24 is obtained without affecting the main clock input, if **JTFRAME_SDRAM96** is defined, the main clock input moves up from 48MHz to 96MHz. The 48MHz clock can the be obtained from clk48 if **JTFRAME_CLK48** is defined too. This implies that the SDRAM will be clocked at 96MHz instead of 48MHz. The constraints in the SDC files have to match this clock variation.

If STA was to be run on these pins, the SDRAM clock would have to be assigned the correct PLL output in the SDC file but this is hard to do because the TCL language subset used by Quartus seems to lack control flow statements. So we are required to do another text edit hack on the fly, which is not nice. Apart from changing the PLL output, when using 96MHz clock the input data should have a multicycle path constraint as it takes an extra clock cycle for the data to be ready. If you just change the PLL clock then you'll find plenty of timing problems unless you define the multicycle path constraint.

This is the code needed:

```
create_generated_clock -name SDRAM_CLK -source \
    [get_pins {emu|pll|pll_inst|altera_pll_i|general[5].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -divide_by 1 \
    [get_ports SDRAM_CLK]

set_multicycle_path -from [get_ports {SDRAM_DQ[*]}] -to [get_clocks {emu|pll|pll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup -end 2

set_multicycle_path -from [get_ports {SDRAM_DQ[*]}] -to [get_clocks {emu|pll|pll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold -end 2
```

This only applies to MiSTer. For MiST the approach is different and there are two different PLL modules which produce the SDRAM clock at the same pin. So a single `create_generated_clock` applies to both. Due to different SDRAM shifts used, the multicycle path constraint does not seem needed in MiST.

The script **jtcore** handles this process transparently.

**JTFRAME_MR_FASTIO** enables fast ROM download in MiSTer using 16-bit mode in _hps_io_.

## Clock Enable Signals

Most core modules will need to operate at a frequency different from the master clock, **clk**. This is achieved by using clock enable signals (*cen*), which are high exactly for one pulse cycle. There are several modules in [hdl/clocking](../hdl/clocking) that help creating these *cen* signals but the preferred method is to define them in the cfg/mem.yaml file.

*cen* signals can be defined in terms of a multiplier and a divider, which is handy when the original system follows that method, or with an absolute frequency in hertz. Each definition is tied to a specific JTFRAME clock (clk24, clk48 or clk96) and for absolute value calculations, the **JTFRAME_PLL** macro is taken into account. Thus the desired frequency will be obtained regardless of which clock and which PLL you choose for the design.

Example from **jtroadf** core:

```
clocks:
  clk24:
    - mul: 1
      div: 4
      outputs:
        - cpu4
        - ti1
        - ti2
    - freq: 3579545
      outputs:
        - snd
        - psg
```

For each output listed, the result frequency is divided by 2. Thus cpu4_cen will operate at clk24/4, ti1_cen will be clk24/8 and ti2_cen clk24/16. Similarly, psg_cen will be half the frequency of snd_cen. All signals listed in _outputs_ will have the suffix *_cen* added and they will become input ports to the _game_ module.

You can specify several clock domains, clk24, clk48, etc. If you move _cen_ signals from one domain to another, make sure the right clock is used in the _game_ module too for each respective _cen_.

# Internal JTFRAME Clocks

The clocks passed to the target subsystem (jtframe_mist, jtframe_mister or jtframe_neptuno) are three:

clock     |  Use                    | Frequency
----------|-------------------------|--------------------
clk_sys   | Video & general purpose | same as game clock **clk**
clk_rom   | SDRAM access            | same as clk_sys
clk_pico  | picoBlaze clock         | 48MHz

clk_rom is controlled by the macros **JTFRAME_SDRAM96**

Games can move these frequencies by replacing the PLL (using the **JTFRAME_PLL** macro) but the changes should be within ±10% of the expected values. For example, to use a 6.144 MHz pixel clock use `JTFRAME_PLL=jtframe_pll6144` in the .def file.

JTFRAME_PLL     | PCB crystal |   Base clock    | Pixel clocks  | Used on
----------------|-------------|-----------------|---------------|-------------
jtframe_pll6000 |             |   48/96         | 8 and 6 MHz   | Most JT cores. Used by default
jtframe_pll6144 | 18.43200    |   49.152        | 6.144         | JTKICKER, JTTWIN16, JTFROUND, JTSHOUSE, JTTWIN16, JTVIGIL
jtframe_pll6293 | 25.1748     |   50.3496       | 6.2937        | JTS16, JTOUTRUN, JTSHANON
jtframe_pll6671 | 26.68600    |   ~53.37        | ~6.67         | JTRASTAN

These final frequencies have a slight error with respect to the PCB. For 6.144 and 6.2937MHz, it could be solved by adding one more PLL stage for an external clock of 27MHz. For 6.671MHz, there is no fractional solution in two stages for either a 27 or a 50MHz input clock.

In order to test all clocks and all SDRAM settings quickly, run:

`jtupdate 1942 kicker shanon rastan cps1 -t sidi128 --jobs 2`

The game module input clocks are multiples of the base clock:

 clock input | Default  | jtframe_pll6144
-------------|----------|------------------
clk          |  48      |   49.152
clk96        |  96      |   98.304
clk48        |  48      |   49.152
clk24        |  24      |   24.576

# Pixel Clock

All cores must define two clock enable signals based on clk_rom:

- pxl_cen is the pixel clock. A typical value is 6MHz
- pxl2_cen runs at twice the frequency of pxl_cen

As clock enable signals, these should not be high for more than one clock cycle. Some modules may expect an idle cycle after the active one.

Most cores define these two signals as output ports. They can instead be input ports generated by JTFRAME by defining **JTFRAME_PXLCLK** to be 6, 8 or 16. The 6 and 8 MHz settings support both 48 and 96 MHz SDRAM clocks. The 16 MHz setting requires **JTFRAME_SDRAM96**, producing a 32 MHz `pxl2_cen` and a 16 MHz `pxl_cen` from the nominal 96 MHz clock.

**JTFRAME_PXLCLK** selects a fixed divider of `clk_rom`: 8 or 6 for the 6 and 8 MHz settings at a 48 MHz reference, doubled when **JTFRAME_SDRAM96** is set. The 16 MHz setting uses a divider of 6 at a 96 MHz reference. With a custom **JTFRAME_PLL**, these dividers stay fixed, so the actual pixel frequencies scale with the PLL frequency. For example, a 56 MHz `clk_rom` with `JTFRAME_PXLCLK=6` produces 7 MHz `pxl_cen` and 14 MHz `pxl2_cen` (56/8 and 56/4); the macro names the divider configuration, not a frequency correction.

**JTFRAME_PXL_DIV** overrides the pixel divider with the actual number of system-clock cycles per pixel, including any SDRAM clock doubling. Odd divisors produce alternating intervals for `pxl2_cen`. It also supplies the default **JTFRAME_HSIZE_DIV**.

| JTFRAME_PXLCLK | pxl2_cen | pxl_cen |
|:---------------|:---------|:--------|
| 16 (SDRAM96)   | 32       | 16      |
| 8              | 16       | 8       |
| 6              | 12       | 6       |

For the pixel-enable migration, most cores use the default 48 MHz `clk_rom`:
the 6 MHz setting produces 6/12 MHz pixel enables, and Rumble's 8 MHz setting
produces 8/16 MHz. Rastan's target-dependent PLL output is about 53.37 MHz
`clk_rom`, producing about 6.67/13.34 MHz with the fixed /8 and /4 pixel
dividers. NARC's 96 MHz setting produces
16/32 MHz. Kyukyoku Tiger and Wardner produce 7/14 MHz on MiSTer because their
56 MHz `clk_rom` uses the /8 and /4 dividers; on SiDi128 they retain native
7 MHz enables because the 49 MHz clock divided by 8 would produce 6.125 MHz.
The core migration records list which local CPU, audio and timer enable generators
remain in use, along with target-specific pixel rates and phase notes:
[pixel CE migration notes](../../../doc/pixel-ce-migration.md). Matching nominal
rates do not guarantee edge-for-edge phase equivalence with a former local
divider. For example, in the measured 48 MHz `jtframe_cen48` comparison the
legacy 6 MHz enable first asserts at sampled cycle 1 while the compared
fractional 6 MHz sequence first asserts at cycle 4; both then repeat every 8
cycles, with a 3-cycle phase offset. Migrated cores retain ordinary enables
where their consumers depend on that cadence, and video/timer consumers that
share a pixel domain use the same framework enable. See the migration record
for retained CPU/audio generators, the Toaplan 7 MHz exception and additional
measured phase offsets.
