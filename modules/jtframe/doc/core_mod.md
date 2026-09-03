# MOD BYTE

The *mod byte* is an extra game-specific configuration word. MiST supports only
the first seven bits, whereas MiSTer and Pocket transport two bytes. This
concept was originally leveraged on the JTCPS1 core to mark screen orientation
per game as there were both vertical and horizontal games compatible with the
same JTCPS1 core.

The MiSTer and Pocket ports split the two-byte value into two framework
signals: bits 6:0 become `core_mod[6:0]`, bit 7 is discarded, and bits 15:8
become the per-game `game_vol[7:0]` setting. The second byte is therefore
actively supported, but it is dedicated to sound volume rather than exposed as
additional generic `core_mod` bits.

The *mod byte* configures aspects of JTFRAME, in contrast to bits in the header, which are handled directly by the core's game module. These features are customised per game in order to share a common RBF file among several games. The mod byte is introduced in the MRA file using this syntax:

```
    <rom index="1"><part> 01 80 </part></rom>
```

Here `01` is `core_mod` and `80` is the unity-gain `game_vol` value.

MiST ARC files contain only the seven-bit modifier value:

```
MOD=1
```

This is the meaning for each bit:

Bits | Framework signal      | Meaning
-----|-----------------------|--------
6:0  | `core_mod[6:0]`       | Generic per-game framework options described below
7    | None                  | Reserved and currently discarded
15:8 | `game_vol[7:0]`       | Per-game sound volume

The generic `core_mod` bits are:

Bit | Meaning                | Default value
----|------------------------|--------------
0   | 1 = vertical screen    | 1
1   | 1 = 4 way joystick     | 0
2   | 1 = CCW rotation       | Set by `jtframe mra`
3   | 1 = unfiltered dial    | Dial signals are sent raw to the core
4   | 1 = dial reverse       | Reverse dial direction
5   | 1 = remove black frame | 0
6   | 0/1 => 8/16 pixels or lines per side | Magnitude of the blank-frame removal

 The vertical screen bit is only read if JTFRAME was compiled with the **JTFRAME_VERTICAL** macro. This macro enables support for vertical games in the RBF. Then the same RBF can switch between horizontal and vertical games by using the MOD byte.

Bits 0 and 5 are interpreted together for black-frame removal. When bit 5 is
set, horizontal games (bit 0 clear) shorten `LHBL`, while vertical games (bit 0
set) shorten `LVBL`. Bit 6 selects whether 8 or 16 pixels/lines are removed at
each side of the selected axis. Bit 0's primary meaning remains the game's
screen orientation.

MiST does not support bit 7 or the second byte, so per-game volume is not
available there. MiSTer loads the two bytes from offsets 0 and 1 of MRA ROM
index 1. Pocket writes the same 16-bit value through its MOD memory-mapped
configuration register. In both cases the target logic exposes the upper byte
as `game_vol`, separately from `core_mod`.
