# MiST Derivatives

The MiST firmware was derived from Minimig, but it has served as the basis for other systems:

* SiDi, shares the same MCU and binary firmware
* NeptUNO, comes from Multicore, which seems to be influenced by MiST

Some systems use a different file extension for the RBF

System       | RBF file extension
-------------|---------------------
MiST, SiDi   | rbf
Neptuno      | np1
Multicore 2+ | mcp
Multicore 2  | mc2

## NeptUNO

This system has a primitive I/O and disk management:

* Only direct PS2 and DB9 inputs connected to the FPGA
* The RBF must be renamed to .NP1
* The ROM file must be called like the core file, with the .DAT extension
* The ROM file must be specified in the config string like `P,myrom.dat` but it can also use the format `P,CORE_NAME.dat` and that will match the .dat file with the same name as the .np1
* ARC files are not allowed, a syntax subset seems supported in the form of INI files
* The firmware won't send the ROM file to the core unless the core requests it. The module [pump signal](https://gitlab.com/victor.trucco/Multicore/-/blob/master/common/PumpSignal.v) seems to serve this purpose

The firmware can ask for commands to the core, by sending the code $14, then the code can reply with a byte with the format `CCCKKKKK`

CCC is the "command":

Bits 7:5   | Use
-----------|----------
111        | Read keyboard input
001        | Pump ROM (parameter "p")
011        | OSD Menu (usually F12 key)

The _pump_ command will be executed by loading the file pointed by `P,...dat` in the config string.

`KKKKK` encodes the keyboard and joystick inputs. The source code documents the following values (in decimal):

```
#define KEY_UP  30
#define KEY_DOW 29
#define KEY_LFT 27
#define KEY_RGT 23
#define KEY_RET 15
#define KEY_NOTHING 31
#define KEY_A   0
#define KEY_B   1
#define KEY_C   2
#define KEY_D   3
#define KEY_E   4
#define KEY_F   5
#define KEY_G   6
#define KEY_H   7
#define KEY_I   8
#define KEY_J   9
#define KEY_K   10
#define KEY_L   11
#define KEY_M   12
#define KEY_N   13
#define KEY_O   14
#define KEY_P   16
#define KEY_Q   17
#define KEY_R   18
#define KEY_S   19
#define KEY_T   20
#define KEY_U   21
#define KEY_V   22
#define KEY_W   24
#define KEY_X   25
#define KEY_Y   26
#define KEY_Z   28

```

A sample I/O code can be seen [here](https://gitlab.com/victor.trucco/Multicore/-/blob/master/common/mc2_hid.vhd).


NeptUNO has a 2MB SRAM module too, which JTFRAME does not support.

### Gamepad Button Assignments

[../hdl/neptuno/jtframe_neptuno_io.v](The Neptuno I/O) module expects a Megadrive DB9 controller to work. Special inputs:

Buttons | Use
--------|--------
Start+C | Display, hide OSD
A       | Functions as enter in the OSD
Start+B | Press during 2 seconds to toggle the scan doubler*

* Not implemented yet

## Multicore 2(+)

The MC2 and MC2+ platforms have four buttons, whose functions are expected to be:

Button   |  OSD       | Arcade
---------|------------|--------
0        | up         | 1P
1        | enter      | 2P
2        | down       | coin
3        | open/close | Hold for reset

The arcade functions are not supported.