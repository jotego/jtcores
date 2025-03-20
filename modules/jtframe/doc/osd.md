# OSD Resolution

Platform | Resolution | Buffer | Remarks
---------|------------|--------|------------------
MiST     | 256x64     | 2kB    |
MiSTer   | 256x128    | 4kB    | HD mode +1kB

In both cases, the buffer encodes pixel columns in bytes: each byte contains one 8-pixel row.

# OSD colours

The macro **JTFRAME_OSDCOLOR** should be defined with a 6-bit value encoding an RGB tone. This is used for
the OSD background. The meanins are:

Value | Meaning                 | Colour
------|-------------------------|---------
6'h3f | Mature core             | Gray
6'h1e | Almost done             | Green
6'h3c | Playable with problems  | Yellow
6'h35 | Very early core         | Red

# DIP switches and OSD

The maximum length of DIP switches is 32 bits. To alter the value of DIP switches in simulation use **JTFRAME_SIM_DIPS**.

In MiST, DIP switches are incorporated into the status word. As some bits in the status word are used for other OSD settings, DIP switches are by default located in range 31:16. This is set by the macro **JTFRAME_DIPBASE**, whose **default value is 16**. Note that the MRA should match this, the **base** attribute can be used in the MRA dip definition to shift the switch bits up. Note that this macro must be defined on the **MiSTer** section of **macros.def** for the *jtframe mra* tool to parse it correctly.

Macro                | Effect
---------------------|----------------------------
JTFRAME_SIM_DIPS     | 32-bit value of DIPs used in simulation only
JTFRAME_OSD_LOAD     | Display _load file_
JTFRAME_OSD_NOCREDITS| Do not display _Credits_
JTFRAME_OSD_FLIP     | Display flip option (only for vertical games)
JTFRAME_OSD_NOSND    | Do not display sound options

Status bits in the configuration string are indicated with characters. This is the reference of the position for each character:

```
Bits 0-31 (o in upper case)
bit          00000000001111111112222222222233
  number   : 01234567890123456789012345678901
status char: 0123456789ABCDEFGHIJKLMNOPQRSTUV

Bits 32-63 (o in lower case)
bit          33333333444444444455555555556666
  number   : 23456789012345678901234567890123
status char: 0123456789ABCDEFGHIJKLMNOPQRSTUV

```

The status words are defined in the *cfgstr* files for each target. With the following encoding:

1st char | Meaning
---------|---------
Omn      | option for bits 0-31. m character sets LSB, n sets MSB
o (lower)| same as `O` but for bits 32-63
HnOm     | Option code m, which can be hidden by hide bit n
DnOm     | Option code m, which can be grayed out by hide bit n
J        | Joystick definition
R        | Reset
V        | Core version

## Values used in the status word by JTFRAME

MiST and MiSTer use 64-bit status words, but Neptuno and MC systems only have 32 bits.

bit     |  meaning                | Enabled with macro
--------|-------------------------|-------------------------------------
0       | Reset in MiST           |
1       | Flip screen             | JTFRAME_VERTICAL && JTFRAME_OSD_FLIP
2       | Rotate controls         | JTFRAME_VERTICAL (MiST)
2       | Rotate screen           | JTFRAME_VERTICAL, visibility masked (MiSTer/Pocket)
3-4     | Scan lines              | Scan-line mode (MiST only)
3-5     | Scandoubler Fx          | Scan line mode and HQ2X enable (MiSTer only)
6-7     | FX Volume (00=lowest)   | JTFRAME_OSD_VOL
6-7     | Spinner sensitivity     | MiST cfgstr maps the spinner here, but jtframe_board always looks at 32-33
8       | Sinden Lightgun borders | Mister only, enables white borders for use with Sinden lightguns
9       | Sinden show crosshair   | Mister only, enables crosshair being shown when using Sinden lightguns
10      | Test mode               | JTFRAME_OSD_TEST
11      | Horizontal filter       | MiSTer only
12      | Credits/Pause           | JTFRAME_OSD_NOCREDITS (disables it)
13-15   | Reserved for core use   | CORE_OSD (option char: D,E,F)
16-17   | Aspect Ratio            | MiSTer only, visibility masked
32-33   | Spinner sensitivity     | MiSTer/Pocket only
37-38   | User output options     | MiSTer, selects DB15, UART, etc.
39-40   | Rotate options (MiSTer) | JTFRAME_VERTICAL && JTFRAME_ROTATE (see below)
41      | Vertical crop (MiSTer)  | MiSTer only
42-45   | Crop offset   (MiSTer)  | MiSTer only
46-47   | Scaling style (MiSTer)  | MiSTer only
48      | CRT H scaling enable    | MiSTer only
49-52   | CRT H scaling factor    | MiSTer only, visibility masked
53-56   | CRT H offset            | MiSTer only
57-60   | CRT V offset            | MiSTer only
61-63   |    -- free --           |

Credits/Pause are handled differently in MiSTer vs MiST. For MiSTer, bit 12 sets whether credits will be displayed during pause. For MiST, bit 12 sets the pause. This difference is due to MiST missing key mapping, so I assume that MiST users depend more on the OSD for triggering the pause.

Option visibility in MiSTer is controlled in [jtframe_mister.sv](../target/mister/jtframe_mister.sv) using the `status_menumask` variable.

If **JTFRAME_OSD_VOL** is set, the dip_fxlevel inputs to the game module will vary according to the following table:

OSD display | dip_fxlevel | Remarks
------------|-------------|---------
very low    |   0         |
low         |   1         |
high        |   2         | Default
very high   |   3         |

If **JTFRAME_FLIP_RESET** is defined a change in dip_flip will reset the game. Connect the game module *flip* signal directly to the DIP switch bit if this macro is used. Connecting it to the CPU controlled *flip* bit may create a lock during reset as the CPU flips the bit from the default value to that in the DIP settings.

To add game specific OSD strings, the recommended way is by adding a line to the **.def** file:

```
CORE_OSD=OD,Turbo,Off,On
```
Only one CORE_OSD can be defined, but it an contain multiple values separated by colon.

### Screen Rotation

Screen rotation features require **JTFRAME_VERTICAL** to work. Remember to enable it first in the **.def** file.

Most arcade games have a flip setting among the DIP switches. This is the preferred method to enable it. When that is not possible, using the JTFRAME_OSD_FLIP will add the option to the OSD. The option will appear outside the *DIP Switches* submenu in the OSD.

The current *flip* setting is kept in the **dip_flip** IO signal of the game module. This signal is an input or an output to the **game** module depending on whether JTFRAME_OSD_FLIP is set or unset:

JTFRAME_OSD_FLIP  |  dip_flip type
------------------|----------------
set               | input
unset             | output

Keep it simply defined as *inout* to avoid problems and assign a value to it when you don't use JTFRAME_OSD_FLIP.

JTFRAME_OSD_FLIP helps with the case when the original game did not have a DIP switch for flipping but it is still possible to design the graphics circuitry to have it. However, depending on how the original hardware operated, this may not be possible. An example of this is SEGA System 16. The sprite definition in that system is made in a way that makes very hard to flip the sprites without the game software intervention.

In cases where hardware flip at the base video signal is not possible, you can still flip the image directly in MiSTer by using the frame buffer. To enable this feature use the macro JTFRAME_ROTATE. This will add more options to the *Rotate screen* menu item in the OSD. These options will apply directly to MiSTer's frame buffer.

It is discouraged to use JTFRAME_ROTATE if the game already provides a flip setting through the DIP switches. Doing so can be confusing to the user. JTFRAME_OSD_FLIP is ignored if JTFRAME_ROTATE is defined.

### User Port

The user port supports:

-DB15 joysticks using Villena's interface, support removed with **JTFRAME_NO_DB15**
-A simple UART, which can connect to the cheat engine (**JTFRAME_CHEAT**) or to the core **JTFRAME_UART**)

Depending on the three macros above are set or unset, the OSD menu will show different options in MiSTer.
