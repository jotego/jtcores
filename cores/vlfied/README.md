# JTVLFIED FPGA Arcade Hardware by Andrea Bogazzi

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# Technical Notes

Volfied has no tilemap chip. The background is a player-drawn bitmap that the 68000 writes directly, one 16-bit word per pixel, with a per-bit write mask that turns a masked write into a read-modify-write. It lives in its own SDRAM bank rather than BRAM, where the 512 KB would take almost every M10K block on the device. A double line buffer is filled a line ahead so the per-pixel scanout never reaches SDRAM.

The board shares its 26.686 MHz video crystal with Rastan and runs the same raster, so this core uses the Rastan video timing and takes the PC060HA and PC090OJ implementations from that core unmodified. The C-chip comes from the `jttc0030cmd` module. The only block written for this core is the framebuffer.

The YM2203 SSG outputs are shorted together on the board, so only the loudest of the three passes; `jt03` is instanced with `YM2203_LUMPED(1)` to model it.

The C-chip's internal mask ROM is a device ROM common to every Taito C-chip game and is not part of the per-machine dump. `cchip.zip` has to be available alongside the game set for the MRA to be assembled.
