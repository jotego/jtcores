# MOD BYTE

The *mod byte* is an extra game-specific configuration word. MiST supports only
the first seven bits, whereas MiSTer and Pocket transport up to three bytes. This
concept was originally leveraged on the JTCPS1 core to mark screen orientation
per game as there were both vertical and horizontal games compatible with the
same JTCPS1 core.

The MiSTer and Pocket ports split the value into framework signals: bits 6:0
and 17:16 become `core_mod`, bit 7 is discarded, and bits 15:8 become the
per-game `game_vol[7:0]` setting. MiSTer also exposes bit 18 when compiled
with `JTFRAME_CRT480I`, to select interlaced analog video.

The *mod byte* configures aspects of JTFRAME, in contrast to bits in the header, which are handled directly by the core's game module. These features are customised per game in order to share a common RBF file among several games. The mod byte is introduced in the MRA file using this syntax:

```
    <rom index="1"><part> 01 80 </part></rom>
```

Here `01` is the low `core_mod` byte and `80` is the unity-gain `game_vol`
value. A third byte is emitted when bits 16, 17 or 18 are set.

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
18   | `core_mod[18]`        | Interlaced 15 kHz analog video on MiSTer with `JTFRAME_CRT480I`

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
18  | 1 = interlaced 15 kHz analog video | 0 (native video); MiSTer only

 The vertical screen bit is only read if JTFRAME was compiled with the **JTFRAME_VERTICAL** macro. This macro enables support for vertical games in the RBF. Then the same RBF can switch between horizontal and vertical games by using the MOD byte.

Black-frame removal is independent of the screen-orientation bit. Bits 5:6
shorten `LHBL`, and bits 3:4 shorten `LVBL`. The magnitude bit is only used
when the matching enable bit is set.

MiST does not support bit 7 or the bytes above it, so per-game volume and dial
options are not available there. MiSTer loads the bytes from MRA ROM index 1.
Pocket writes the same value through its MOD memory-mapped configuration
register. In both cases the target logic exposes bits 15:8 as `game_vol`,
separately from `core_mod`.

## Interlaced analog video

With `JTFRAME_CRT480I` enabled in `cfg/macros.def`, MiSTer uses bit 18 to
select the `jtframe_crt_480i` converter for the analog output. Clearing the
bit selects native analog video. Both selections use the same RBF and game
ROMs. HDMI keeps the native picture through the scaler; with direct video
enabled, HDMI carries the converted interlaced picture instead.

The bytes in MRA ROM index 1 are ordered from least to most significant.
For example, NARC's interlaced MRA contains:

```xml
<rom index="1">
    <part>00 B5 04</part>
</rom>
```

`B5` remains the per-game volume. The third byte `04` sets bit 2 of that
byte, which is bit 18 of the complete configuration word. The native MRA
contains `00 B5`, so bit 18 stays clear. Bits 16 and 17, if needed for dial
options, can coexist with bit 18 in the third byte.

To distribute both MRA versions, enable this in `cfg/mame2mra.toml`:

```toml
[video]
interleaved_MRAs = { machine="narc" }
```

Running `jtframe mra narc` then generates both `Narc (rev 7.00).mra` and
`Narc (15kHz) (rev 7.00).mra`, plus matching interlaced MRAs for the selected
clone sets. Each additional MRA goes beside its regular counterpart, whether
that is in the main folder or an alternative folder. Only the additional MRAs
set bit 18; the native `.mod` file and Pocket configuration retain their
original values.

`interleaved_MRAs` uses the usual `machine`, `machines`, `setname` and
`setnames` selectors. A machine selector includes its clone sets; a setname
selector limits generation to that specific set. For example,
`interleaved_MRAs = { setnames=["narc", "narc6"] }` creates interlaced MRAs
only for those two sets. Omitting `interleaved_MRAs` disables the extra files.
