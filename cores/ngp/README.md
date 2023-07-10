# NeoGeo Pocket Compatible FPGA core by Jotego

Please support the project
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# System Details

| unit    | memory (kB) | remarks        |
|:--------|:------------|:---------------|
| T800H   | 12+4        | upper 4 shared |
| Z80     |  4          | shared         |
| Fix     |  8          |                |
| Scroll  |  4          | 2kB per layer  |
| Objects |   .25       |                |
| Total   | 32          |                |

- Is the video chip connection to the data bus 16 or 8 bits?
- Palette RAM is 16-bit access only and has no wait states

Because of the awkward video timing, the system needs some sort of buffer to output analog video. It is not clear whether it can be done with the amount of BRAM available in MiST/SiDi. That's why the core only targets MiSTer and Pocket right now.

# Key Mapping

- A, B buttons are mapped to the first two buttons in the gamepad
- Start button is mapped to _1P_ (keyboard key `1`)
- Power button is mapped to _coin_ (keyboard key `5`)

# Simulation & Debugging

In order to simulate with a cartridge, this has to be named `cart.bin`. The firmware should be called `rom.bin`. Check out [JTFRAME documentation](../../modules/jtframe/doc/sdram.md)

## MiSTer

MiSTer scaler automatically handles the awkward video format. This means that the core will only work via HDMI. MiSTer's analog output may work if it is configured to output the scaler video. Compiling the sound CPU is most likely needed for the system to work correctly. All this means that you need to run full compilations for all tests: `jtcore ngp -mr`

## MAME

Supply the cartridge name with `-cart`. It is possible to boot with no cartridge too.

`mame ngp -cart cartridge.ngp`

F1 serves as the power button. You probably need to press F1 if the emulator shows a blank screen on start up.

MAME may save the main CPU RAM (12kB) to `~/.mame/nvram/ngp`. Then it will boot from it the next time MAME is run. When it boots from NVRAM, it starts at a different PC address (PC=FF1800). This skips the configuration screen and tries to emulate the standby mode of the original hardware.

You may have NVRAM savings enabled by default, which can make the boot process confusing. Disable it in the `~/.mame/mame.ini` by setting `nvram_save 0`. If you want to save the NVRAM at some point, call MAME with `-nvram_save`

# Cartridge

Manufacturer ID 0x98

Size (kB) | Device ID | Chip count
----------|-----------|-----------
32~512    |   0xAB    |    1
1024      |   0x2C    |    1
2048      |   0x2F    |    1
4096      |   0x2F    |    2

# Contact

* https://twitter.com/topapate
* https://twitter.com/jotegojp
* https://github.com/jotego/jtcores/issues

# Thanks to July 2023 Patrons
