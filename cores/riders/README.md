# JTRIDERS FPGA core Compatible with Konami's Sunset Riders hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Project source code hosted at http://www.github.com/jotego/jtcores
License: GPL3, you are obligued to publish your code if you use mine

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# Supported Systems

This FPGA core is compatible with the following arcade PCBs:

- Sunset Riders
- TMNT Turtles in Time
- X-Men (not on MiST devices)

Due to limitations in the internal RAM memory of small FPGA devices, X-Men will not run on MiST FPGAs. The SiDi version of the core does not feature the video bright feature of the original board.

# Game Configuration

This game does not use DIP switches but a small EEPROM to save the configuration. Access to the configuration by pressing F2 on your keyboard or pressing button 1 and coin in the Analogue Pocket. Follow the game menu to alter the configuration from that point on.

# Board Differences

Game           | Object Chipset            | Sound Chipset             | Remarks
---------------|---------------------------|---------------------------|---------------------
xmen		   | 053246/053247             | 054539/054321             | same object chipset as simpsons
ssriders       | 053244/053245             | 053260                    | objects like parodius. Protection chip for object RAM