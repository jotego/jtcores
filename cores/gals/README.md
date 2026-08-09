# JTGALS FPGA Arcade Hardware by Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# KNOWN ISSUES

## SiDi128

Screen rotation is not available for this core when the line-frame buffer is
enabled. Gals Panic uses the target SDRAM for the sprite frame buffer, and
screen rotation needs that same SDRAM path.
