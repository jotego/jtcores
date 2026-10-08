# JTTMNT FPGA core Compatible with Konami's TMNT hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Project source code hosted at http://www.github.com/jotego/jtcores
License: GPL3, you are obligued to publish your code if you use mine


Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# Hardware Information

This core is based on the official schematics for this system and the [reverse engineering work done by Furrtek](https://github.com/furrtek/SiliconRE/tree/master/Konami). Contrary to Furrtek's own FPGA core, this implementation tries to make the RTL code more readable and targeted to modern hardware. Both implementations should be equivalent in the critical aspects.

# Service Mode

When entering service mode, the system will go into a lengthy video ROM check process. At some point, it will look like the screen just went crazy. That is normal. If you wait long enough, the check results will be presented and you can on with the rest of the service menu.

The core does not currently support video ROM checks, so the ROMs will be reported as BAD. This does not affect gameplay.

# Thunder Cross II Support

Contributed by *niknakniknak* and reviewed by Jose Tejada. The PCB belongs to the same family of TMNT so even if we do not have schematics for it, the confidence is quite high on this game.

The sound FM-PCM balance was measured on the PCB.

# Credits

Special thanks to [Furrtek](http://furrtek.free.fr/) for all his open source research. Thanks too to DJ Hardrich for lending this PCB for analysis.
