# Style Conventions

The following guide lines are generally applied to signal and module names in JTFRAME and JT cores.

## Instances

- Instance names start by *u_*, which stands for _unit_
- Instance names for *jtframe_* modules do not repeat the *jtframe_* but only the module surname. For instance `jtframe_ram u_ram`
- The instance order in the game module should be game, sub-cpu, sound, video and sdram

## Modules

- Each verilog file contains only one module
- The name of the module matches the name of the file
- The top-level of a core ends in *game*
- Parameter names should be in upper case

## Signals

- Blanking signals are called LHBL and LVBL, active low. These names come from the old CAPCOM schematics
- Active-low signal end in *_n*
- A signal ending in *_l* refers to a 1-clock delayed version of another signal
- *pre_* and *post_* suffixes refer to the same signal path at different points
- *nx_* refer to the next value a signal will take
- All address spaces are referred to an 8-bit word. This means that if you use a 16-bit bus, the address should start at 1, not zero. If you use a 32-bit bus, it should start at 2. For instance:

```
    wire [13:0] address_bus_for_8bit_data;
    wire [13:1] address_bus_for_16bit_data;
    wire [13:2] address_bus_for_32bit_data;
```

this approach has been common practice in the industry at least for the last four decades