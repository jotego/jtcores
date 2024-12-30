# JTFLSTORY, FPGA hardware compatible with Taito's FairyLand Story software

This work is based on the schematic work we did on an original FairyLand arcade
PCB. The board turned out to be full of surprises.

# Differences with Emulation (as of Dec. 2025)

The following features are present on the hardware and seem to be missing on
emulators:

- sprite count limited to 8 per line without blinking, more than 8 sprites can be shown but some will blink
- there is a RAM that sets the scroll-sprite priority, not fixed values
- background tile flip control bits can be ignored by means of a global control bit
- some MCU features are missing, such CPU bus sharing via bus request/acknowledgement
- there are a lot of analog audio features that the sound CPU can control, such as balance, trebble, bass...
  the balance feature of amplifier TA7630 is used to alter the relative volume of the two MSM5232 audio channels, so it plays an important role in how the melody sounds
- there are two palette banks (not one)
- there are two background tile banks (not one)
- the priority bits for sprites and scroll tiles are three and two (fewer used in emulation)
- there is support for a light gun on the board
