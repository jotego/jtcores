# MOD BYTE

The *mod byte* is an extra game-specific configuration word. MiST supports only
the first seven bits, whereas MiSTer and Pocket transport up to three bytes. This
concept was originally leveraged on the JTCPS1 core to mark screen orientation
per game as there were both vertical and horizontal games compatible with the
same JTCPS1 core.

The MiSTer and Pocket ports split the value into framework signals: bits 6:0
and 17:16 become `core_mod`, bit 7 is discarded, and bits 15:8 become the
per-game `game_vol[7:0]` setting.

The *mod byte* configures aspects of JTFRAME, in contrast to bits in the header, which are handled directly by the core's game module. These features are customised per game in order to share a common RBF file among several games. The mod byte is introduced in the MRA file using this syntax:

```
    <rom index="1"><part> 01 80 </part></rom>
```

Here `01` is the low `core_mod` byte and `80` is the unity-gain `game_vol`
value. A third byte is emitted when bits 16 or 17 are set.

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
17:16| `core_mod[17:16]`     | Dial options on MiSTer and Pocket

The generic `core_mod` bits are:

Bit | Meaning                | Default value
----|------------------------|--------------
0   | 1 = vertical screen    | 1
1   | 1 = 4 way joystick     | 0
2   | 1 = CCW rotation       | Set by `jtframe mra`
3   | 1 = remove LVBL black frame | 0
4   | 0/1 => 8/16 lines per side | Magnitude of the LVBL removal
5   | 1 = remove LHBL black frame | 0
6   | 0/1 => 8/16 pixels per side | Magnitude of the LHBL removal
16  | 1 = unfiltered dial    | Dial signals are sent raw to the core
17  | 1 = dial reverse       | Reverse dial direction

 The vertical screen bit is only read if JTFRAME was compiled with the **JTFRAME_VERTICAL** macro. This macro enables support for vertical games in the RBF. Then the same RBF can switch between horizontal and vertical games by using the MOD byte.

Black-frame removal is independent of the screen-orientation bit. Bits 5:6
shorten `LHBL`, and bits 3:4 shorten `LVBL`. The magnitude bit is only used
when the matching enable bit is set.

MiST does not support bit 7 or the bytes above it, so per-game volume and dial
options are not available there. MiSTer loads the bytes from MRA ROM index 1.
Pocket writes the same value through its MOD memory-mapped configuration
register. In both cases the target logic exposes bits 15:8 as `game_vol`,
separately from `core_mod`.
