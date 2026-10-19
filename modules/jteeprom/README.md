# JTEEPROM

Verilog modules compatible with common EEPROM chips such as 93C46 or 93C06 by Jose Tejada (jotego)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

# Related Repositories

The following repositories use these modules

- [JTCORES](https://github.com/jotego/jtcores), FPGA cores compatible with multiple arcade systems
- [JTCPS](https://github.com/jotego/jtcps1), compatible FPGA core for CAPCOM arcade system
- [JTPANG](https://github.com/jotego/jtpang), compatible FPGA core for CAPCOM/Mitchell Pang hardware

# Dump Interface

The modules have a dump interface with the same data width as the memory itself. But, there is a [wrapper](hdl/jt9346_16b8b.v) to provide a consistent 8-bit dump interface regardless of the memory width.

[JTFRAME](https://github.com/jotego/jtframe) expects an 8-bit interface, so the wrapper is advised.

# Test waveforms

This can obtained by dumping to the error.log file the commands sent by the CPU in the Cadillacs'n Dinosaurs game:

```mame dino -debug -log```

And then

```wp f1c006,1,w,1,{logerror "%d - %d - %d\n", (wpdata&0x80)>>7,(wpdata&0x40)>>6,wpdata&1;go}```

After booting, the error.log will contain the read access done by the game. If you go into the test menu, and change the settings, the error.log will contain the write commands.
