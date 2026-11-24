# JTCAL50 FPGA core Compatible with Seta's Caliber 50 hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

# CPU Bus Timing

The F4B 74LS74 (clocked by the 8 MHz pixel clock, D = NAND(H1,H0), set while VGFX is inactive) lets DTACK through for one pixel clock after H[1:0]==3. The CPU gets the X1 video RAM once every 4 pixels. This is a board wait, so the core does not recover those CPU clocks.

These wait states were derived from the schematics and have not been checked on a PCB yet.
