# Cheat Engine

The cheat engine consists of a Picoblaze compatible CPU that has full access
to SDRAM bank zero. This tiny CPU can be used to implement the MAME cheats,
as well as it can be used to perform other functions, like high-score
extraction and help in debugging the system during development.

![Cheat Subsystem](cheat.png)

The cheat engine comes with a cost in FPGA space usage and synthesis time, so
it is disabled by default. It is enabled by defining the macro **JTFRAME_CHEAT**.

See the [cheat tutorial](cheat-tutorial.md) for learning how to add new cheats.

## Compilation Requirements

Note that if **JTFRAME_CHEAT** is set, you will need a cheat.hex file in the compilation folder. As with other hex files, normally you place it in the mist folder and _jtcore_ will link it from there when you compile other targets. It is also possible to place it in the _hdl_ folder.

The _cheat.hex_ contains the 18-bit hex words for the firmware, and can be generated as described in the [cheat tutorial](cheat-tutorial.md).

## MRA File

Cheats are added to the MRA file like this:

```
<cheats>
    <dip name="Infinite Credits" bits="0" ids="No,Yes"/>
    <dip name="P1 Infinite Lives" bits="1" ids="No,Yes"/>
    <dip name="P1 Invincibility" bits="2" ids="No,Yes"/>
</cheats>
```

It basically follows the same syntax as the DIP switches, but the top element
is called `<cheats>`. There are a maximum of 32 bits available. The MiSTer
firmware must be older than 4th June 2021 to support it.

The MRA also needs to load the PizoBlaze firmware in ROM position 16:

```
<rom index="16" zip="cheat.zip" md5="None">
    <part name="mycheat.bin"/>
</rom>
```

## Port Map

Port (hex) | I/O    |  Usage
-----------|--------|-------------------------
2,1,0      | I/O    | SDRAM address (24 bits)
4,3        | O      | data to SDRAM
5          | O      | SDRAM write data mask, only bits 1,0. Active low
7,6        | I      | data read from SDRAM
6          | O      | bit 0 = board LED
8-B        | I/O    | VRAM control (see below)
C-F        | I/O    | Game module communication (see below)
10-13      | I      | cheat flags (meaning defined in MRA file)
14-17      | I      | board status 32-bit word (17=MSB)
18         | I      | 1P joystick
1A         | I      | 1P joystick left  analogue stick X
1B         | I      | 1P joystick left  analogue stick Y
1C         | I      | 1P joystick right analogue stick X
1D         | I      | 1P joystick right analogue stick Y
20-2C      | I      | Time information (see below)
48         | I      | 2P joystick
4A         | I      | 2P joystick left  analogue stick X
4B         | I      | 2P joystick left  analogue stick Y
4C         | I      | 2P joystick right analogue stick X
4D         | I      | 2P joystick right analogue stick Y
30-33      | O      | Lock key
34         | I/O    | UART Rx/Tx data
35         | I      | UART status {rx_error,2'b0,tx_busy,rx_rdy}
40         | O      | Resets the watchdog
80         | O      | Starts SDRAM read
80         | I      | Reads peripheral status (bits 7:6)
C0         | O      | Starts SDRAM write

Time information

Port (hex) | I/O    |  Usage
-----------|--------|-------------------------
20-23      | I      | Bootup timestamp
24-27      | I      | build timestamp
28-2B      | I      | current timestamp
2C         | I      | frame counter

Uses the credits VRAM to display information (JTFRAME_CREDITS required):

Port (hex) | I/O    |  Usage
-----------|--------|-------------------------
8          | O      | VRAM column address (bits 4:0)
9          | O      | VRAM row address (bits 4:0)
A          | I/O    | VRAM reads or writes
B          | O      | VRAM control, see below

VRAM control port (B)

Bit   |   Usage
------|----------
0     | Sets credits OSD to be controlled by the picoblaze
1     | dims the top half of the screen
2     | dims the bottom half of the screen

The screen is dimmed only if bit 0 is set too

Communication with game module

Port (hex) | I/O    |  Usage
-----------|--------|-------------------------
C          | O      | Status address (JTFRAME_STATUS required)
D          | I      | Status data from game
F          | I      | Debug bus

The peripheral status bits are read from port 0x80:

Bit   |  Meaning
------|--------------
7     | Bus ownership, when high the Picoblaze is controlling the SDRAM
6     | high if a PicoBlaze started SDRAM transaction has not finished
5     | Low during vertical blanking
4:2   | Reserved
1     | Beta period has expired
0     | System is locked

The following constant can be used in the assembler code for the ports:

```
constant LED,      6
constant VRAM_COL, 8
constant VRAM_ROW, 9
constant VRAM_DATA,A
constant VRAM_CTRL,B
constant ST_ADDR,  C
constant ST_DATA,  D
constant DEBUG_BUS,F
constant FLAGS,    10
constant BOARD_ST0,14
constant BOARD_ST1,15
constant BOARD_ST2,16
constant BOARD_ST3,17
constant JOY1,     18
constant ANA1RX,   1C
constant ANA1RY,   1D
constant FRAMECNT, 2c
constant KEYS,     30
constant UART_DATA,34
constant UART_ST,  35
constant WATCHDOG, 40
constant JOY2,     48
constant ANA2RX,   4C
constant ANA2RY,   4D
constant STATUS,   80
```

## Future Features

The following features will be added to the cheat subsystem

* Keyboard and joystick manipulation, both input and output
* Interrupt at vertical blank -currently a bug in the softcore prevents it
* Data dump via high-score/NVRAM interfaces

## Resources

* [PicoBlaze User Guide](https://www.xilinx.com/support/documentation/ip_documentation/ug129.pdf)
* [Open PicoBlaze Assembler](https://github.com/kevinpt/opbasm)
* [Macro support for opbasm](http://kevinpt.github.io/opbasm/rst/m4.html)
* [PicoBlaze VHDL generic version](https://github.com/krabo0om/pauloBlaze)
* [Holy Cheat! Guide](http://cheat.retrogames.com/download/holycheat!.zip)