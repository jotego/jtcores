# JTFRAME target for ZXTRES (A35T), ZXTRES+ (A100T), ZXTRES++ (A200T)

target by @somhi

## Target information

This target is based on [DeMiSTify](https://github.com/robinsonb5/DeMiSTify) firmware by Alastair M. Robinson. DeMiSTify is code to support porting MiST cores to other boards. 

ZXTres is an evolution of the well-known ZXUno project to a larger field-programmable gate array. ZXTres provides modern video output through DisplayPort, VGA and analog audio (I2S or DeltaSigma DAC selection). It's based on the QMTECH Artix7 Xilinx Board.

- **Models**: There are 3 different models: **ZX-Tres** (Xilinx Artix A35T FPGA), **ZX-Tres+** (fpga A100T) and the **ZX-Tres++** (fpga A200T) .
- **On-board memory**: ZX-Tres 2 MB of SRAM and 32 of SDRAM. The ZX-Tres+ and ZX-Tres++ models 2MB of SRAM and 64 MB of SDRAM.
- **32 MB SPI Flash**. Contains the firmware, esxDOS, Spectrum roms and cores.
- **Video**: DAC 888 RGB (true color). Output via DisplayPort (digital output 640x480) and VGA (VGA and RGB) connectors
- **Sound out**: 3.5mm Jack. Delta Sigma and I2S.
- **Sound in**: 3.5mm Jack.
- **EDGE Connector**: Opens the possibility of using external devices such as those used by the Spectrum, MSX cartridges, etc.
- **Joysticks**: 2 DB9 type joystick inputs compatible with Atari joysticks (2 buttons) and Megadrive pads (8 buttons).
- **2 PS/2 inputs**: To connect a keyboard and mouse.
- **1 USB input**: It is not yet operational although it is expected to be operational in the future to connect mice or keyboards.
- **Micro SD**

## Resources

* https://github.com/zxtres

* https://antoniovillena.es/store/

