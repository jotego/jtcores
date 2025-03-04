# Debugging

If JTFRAME_RELEASE is not defined, the debug features can be used. Also check [the NVRAM saving](doc/sdram.md) procedure as it can be useful for debugging.

## GFX Enable Bus

keys F7-F10 will toggle bits in the gfx_en bus. After reset all bits are high. These bits are meant to be used to enable/disable graphic layers.

## Sound Channel Enable Bus

Shift + keys F7-F12 will toggle bits in the snd_en bus. These bits are handled automatically by games using **mem.yaml** to define audio. Each key will toggle on and off and audio channel during test builds.

## Generic 8-bit Debug bus

If JTFRAME_RELEASE is not defined, keys + and - (in a Spanish keyboard layout) will increase and decrease the 8-bit debug_bus.

By default, debug_bus is increased (decreased) by 1. If SHIFT is pressed with +/-, then the step is 16 instead. This can be used to control different signals with each *debug_bus* nibble. However, the bus is always increased as a byte, so be aware of it. Pressing CTRL with +/- will reset the *debug_bus* to zero. Press shift+1-0 keys (main keyboard, not keypad) to individually togle each bit of the debug bus.

The game must also define an output bus called *debug_view*, which will be shown on screen, binary encoded. This is a quick way to check signal values. Assign it to 8'h0 if you don't need it. For most sophisticated probe needs, it is better to use the [cheat engine](cheat.md) or the FPGA signal tap facilities.

It is recommended to remove the *debug_bus* once the core is stable. When the core is compiled with **JTFRAME_RELEASE** the *debug_bus* has a permanent zero value and there is no on-screen debug values.

## System Info

By pressing SHIFT+CTRL, the core will switch from displaying the regular *debug_view* to *sys_info*. This 8-bit signals carries information from modules inside JTFRAME, aside from core-specific information. This is available as long as **JTFRAME_RELEASE** was not used for compilation. The *debug_bus* selects which information to display. Note that *sys_info* is shown in a **reddish color**, while *debug_view* is shown in white.

  st_addr    |  Read
-------------|-------------------------------------------------------
  00??_????  |  Frame count in BCD (hundreds. Set st_addr[0] for tenths/units)
  01??_????  |  Audio information (see below)
  0111_00??  |  IOCTL status { gfx_en[0:3], 1'b0, ioctl_ram, ioctl_cart, ioctl_rom }
  0111_0100  |  dipsw[ 7: 0]
  0111_0101  |  dipsw[15: 8]
  0111_0110  |  dipsw[23:16]
  10??_????  |  SDRAM stats
  1100_????  | { core_mod[3:0], dial_x, game_led, dip_flip }
  1101_????  |  Joysticks and inputs
  1110_????  |  Crosshair coordinates
  1111_????  |

See core_mod description [here](osd.md)

### Frame Count

This is the total number of frames since the last reset. The count gets halted during pause.

st_addr[1:0] |  Read
-------------|-----------
  0          | bits 15- 8 (BCD)
  1          | bits  7- 0 (BCD)
  2          | bits 23-16 (BCD)

### Audio Information

If the core exercises the *sample* signal, JTFRAME can report the current sample rate.

st_addr[7:4] |  Read
-------------|-----------
  0          | 8-bit VU (average power)
  5, [1:0]=0 | 1-bit VU (signals sound activity per channel)
  5, [1:0]=1 | Channel enable bits
  5, [1:0]=2 | Sample rate in kHz (BCD)
  6          | Sound volume (gain set by the user/MRA)

### Joysticks

See [jtframe_sys_info.v](../hdl/debug/jtframe_sys_info.v)

st_addr[3:0] | Read
-------------|---------
 0           | game_joy1[7:0]
 1           | {game_coin[0],game_start[0],game_joy1[9:4]}
 2           | {rot,game_tilt,game_test,game_service,game_coin[1:0],game_start[1:0]}
 3           | joyana_l1[ 7:0]
 4           | joyana_l1[15:8]
 5           | mouse_dx[8:1]
 6           | mouse_dy[8:1]
 7           | mouse_f

### SDRAM, IOCTL and DIPSW

IOCTL status { 3'd0, ioctl_ram, 2'd0, ioctl_cart, downloading }

#### SDRAM Information

The number of SDRAM access done in a frame gets displayed. See [jtframe_sdram_stats](../hdl/sdram/jtframe_sdram_stats.v) for details. Note that the access count is divided by 4096, for display convenience. The SDRAM stats are as follow depending on the value of *st_addr* (which is the same as the debug_bus in MiST).

The SDRAM numbers are not in BCD, but in plain binary. Rather than the absolute number, the interesting thing about the SDRAM report is the relative usage. A good design should try to balance access counts among all banks.

st_addr     |  Read
------------|-----------
bit 5 set   | Combined access in all banks
bit 5 clear | bits 1:0 select the bank for which stats are shown
bit 4 clear | Show access count divided by 4096
bit 4 set   | Show access count divided by 256 (may overflow)
bits 3:2=0  | Show frame stats
bits 3:2=1  | Show active region stats
bits 3:2=2  | Show blank region stats

## Target Info

By pressing SHIFT+CTRL again, the core displays an 8-bit signal defined by the JTFRAME target subsystem. This information is shown in blue. The MiSTer target uses this feature to show the status of the [line-frame buffer](../hdl/video/jtframe_lfbuf_ddr_ctrl.v).

### MiST Target Info

Fixed information with MiST base module internal status. The eight bits correspond to:

`{ osd_shown, 1'b0, osd_rotate[1:0], 1'b0, no_csync, ypbpr, scan2x_enb }`

## Generic SDRAM Dump

The SDRAM bank0 can be partially shadowed in BRAM and download as NVRAM via the NVRAM interface. This requires the macros JTFRAME_SHADOW and JTFRAME_SHADOW_LEN to be defined. The MRA file should also enable NVRAM with a statement such as:

```
<nvram index="2" size="1024"/>
```

It is not possible to use JTFRAME_SHADOW and JTFRAME_IOCTL_RD at the same time.

## Helper Modules

- jtframe_simwr_68k replaces a M68000 in simulation and writes a sequence of values from a CSV file to the data bus
- jtframe_sim_sndcmd replaces the main CPU and produces 8-bit commands and interrupts to the sound CPU at given frames

## Frequency Counter

Sometimes it is useful to measure an internal frequency. The module [jtframe_freqinfo](../hdl/clocking/jtframe_freqinfo.v) provides this information. It needs to know the clock frequency in kHz and it provides the measured frequency in kHz too.

## Using Signal Tap

Compile the core normally using `jtcore` one time. You don't need to wait until the compilation is done. This will create the Quartus project files. After that, you can load the project in Quartus and re-compile with Signal Tap enabled.

## Simulation With Joystick Inputs

Using `jtsim -inputs` will read a *sim_inputs.hex* file and apply its contents to the simulation. Use `jtsim -h` to see the format of this file. In MiST and SiDi, it is possible to compile any core with `JTFRAME_INPUT_RECORD` and then use the `Save NVRAM` OSD menu option to create a *CORE.RAM* file. This macro requires other definitions that are added by jtframe but only when the macro is defined in *macros.def*. Do not define it directly in the `jtcore` command line.

This *.RAM* file is converted to *sim_inputs.hex* by running `jtutil inputs path-to-.ram`.

## Debugging information from MiSTer

Connect a mini USB cable to the MiSTer and use the `mr-sniff` script to dump the debug information to the file _mr.log_. You can use `uniq mr.log` to remove much of the duplication.