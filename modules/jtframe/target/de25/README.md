# DE25-Nano

From a configured JTFRAME checkout, generate the Ghosts ’n Goblins synthesis project with

```sh
jtcore gng -t de25
```

The generated project is `cores/gng/de25/jtgng.qpf`. Its `files.qip` lists the HDL in the checkout. GNG uses the JT12 submodule and its JT49 submodule.

To make a standalone copy, run this from the repository root:

```sh
modules/jtframe/target/de25/copy-project.py gng
```

The folder to zip is `release/jtgng-de25/`. Open `jtgng.qpf` inside it.

The board sources come from MiSTer-DE25-Nano revision `4b2aef2cd3656099155e87fe2468ae80a3db83de`. The `platform/de25_mister_menu_top.sv` file defines the active top, `de25_mister_top`. It instantiates the JTFRAME `emu` on the shared framework's 46-bit HPS bus. The standalone copy’s `sys/` contains the entire upstream `shared/mister/sys` distribution. The manifest selects the framework modules used by the persona. The OSD incorporates the platform's Menu patches 0006, 0007 and 0009 through 0011. The clocked HQ2x output is declared as a register.

## Game clocks

Set `JTFRAME_PLL` in the core's `cfg/macros.def` as usual. GNG uses the default 48 MHz game clock derived from the board's fixed 50 MHz reference. Pac-Land already sets `JTFRAME_PLL=jtframe_pll6144`. Running `jtcore paclan -t de25` selects a 49.152 MHz external game reference (8 × 6.144 MHz). The generated QSF passes this rate to the startup RTL, the game IOPLL recipe and the timing constraints. The IOPLL supplies the game clock, half and double that rate, and a separate phase-shifted SDRAM clock. `JTFRAME_SDRAM96` doubles the SDRAM clock.

On a Rev. B board the Si5332B OUT0 feeds `CLOCK1_50`. A persona that needs this output first measures it against the fixed `CLOCK0_50`. If a previous core or loader has already supplied the requested frequency, startup can proceed without register writes. Otherwise the FPGA needs the U24-to-GPIO1 I²C bridge. The upstream Menu reads the chip over this bridge. [Upstream board wiring and measurements](https://github.com/ahmadexp/MiSTer-DE25-Nano/blob/4b2aef2cd3656099155e87fe2468ae80a3db83de/mister-de25/SI5332B.md)

The programmer reads the existing routing and derives the VCO frequency from the 50 MHz OUT1 integer divider. It programs the inactive bank of a powered fractional divider available to OUT0, then switches OUT0 to that divider. Startup requires a supported divider ratio and three successive 1 ms measurements within 2 kHz of the requested reference. The game and SDRAM wait for the game IOPLL to lock. A board with incompatible factory routing or both fractional dividers powered down needs an independently prepared clock configuration. The register sequence has been simulated. The factory divider settings and actual clock on a Rev. B unit still need hardware verification. [Si5332 reference manual, sections 7 and 11](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/reference-manuals/si5332-rm.pdf)

## Building the FPGA image

Source generation runs without Quartus. FPGA fitting requires the Agilex 5 device backend, generated PLL IP, the licensed rev-B GHRD in `ip/terasic-ghrd`, and the matching FDCD HPS configuration. Run the Tcl recipes from the generated project's `ip/` directory. The V2 persona flow uses the Menu's synthesized FDCD partition with `DE25_HPS_PARTITION_MODE=reuse` and `DE25_HPS_PARTITION_QDB` pointing to that QDB. PLL solver results and timing closure still need verification.
