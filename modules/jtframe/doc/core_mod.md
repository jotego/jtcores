# MOD BYTE

The *mod byte* is an extra 7-bit word that MiST uses to configure cores. This concept of game-specific configuration was originally leveraged on the JTCPS1 core to mark screen orientation per game as there were both vertical and horizontal games compatible with the same JTCPS1 core.

The MiSTer and Pocket ports of JTFRAME also support this extra information, although the firmware implementation is different.

The *mod byte* configures aspects of JTFRAME, in contrast to bits in the header, which are handled directly by the core's game module. These features are customised per game in order to share a common RBF file among several games. The mod byte is introduced in the MRA file using this syntax:

```
    <rom index="1"><part> 01 </part></rom>
```

And in the ARC file with

```
MOD=1
```

This is the meaning for each bit. Note that core mod is only 7 bits in MiST.

Bit  |    Meaning            | Default value
-----|-----------------------|--------------
 0   |  1 = vertical screen  |     1
 1   |  1 = 4 way joystick   |     0
 2   |  1 = CCW rotation     | Set by jtframe mra
 3   |  1 = unfiltered dial  | Dial signals are sent raw to the core
 4   |  1 = dial reverse     | Reverse dial direction
 5   |  1 = expand blanking  |     0
 6   |    0/1=>8/16 pixels   | Magnitude of the blanking expansion

 The vertical screen bit is only read if JTFRAME was compiled with the **JTFRAME_VERTICAL** macro. This macro enables support for vertical games in the RBF. Then the same RBF can switch between horizontal and vertical games by using the MOD byte.

 Although MiST does not support a second byte, or even bit 7 in the first one, the second byte is used to set the game sound volume.