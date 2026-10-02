# Adding Turbo Force

Turbo Force runs the same chip set as Power Spikes - 68000 + Z80 + YM2610, C7-01 GGA,
VS8904/VS8905 sprites - so the CPU and sound subsystems carry over unchanged. What differs is
the video: **two tile layers, two sprite chips, and a real sprite-versus-tilemap priority**
that Power Spikes does not have.

It belongs in this core, not a new one: `encode_rotation()` in `jtframe mra` sets
`COREMOD_VERTICAL` in the per-MRA coremod byte, so orientation is a runtime flag. The build
needs `JTFRAME_VERTICAL` once and each set carries its own rotation.

## Deltas against Power Spikes

| | pspikes | turbofrc |
|---|---|---|
| orientation | ROT0, 352x240 | **ROT270**, 352x240 rotated |
| tile layers | 1, 64x32 | **2**, 64x64 each, layer 1 transparent on pen 15 |
| sprite chips | 1 | **2**, separate lookup RAM and gfx region each |
| palette | 2048 entries | **1024**, four fixed 256-entry blocks |
| tile code | `code[11:0] \| gfxbank[code[12]]<<12`, 2 banks | `code[10:0] \| gfxbank[b]<<11`, **8 banks**, `b = layer<<2 \| code[12:11]` |
| scroll X | per line from raster RAM | **one value**, `rasterram[7]-11`, applied to every row |
| scroll Y | one register | two, one per layer, `+2` bias on layer 0 |
| main map | mask 0xffffff | `global_mask(0xfffff)` |
| inputs | IN0, IN1, DSW | adds **IN2** at `0ff008` |
| work RAM | one 64 kB block | 64 kB **plus** a second 16 kB at `0f8000` |

Memory map (`turbofrc_map`, all masked to 20 bits):

```
000000-0bffff  ROM 768 kB        0e0000-0e3fff  sprite lookup RAM 0
0c0000-0cffff  work RAM 64 kB    0e4000-0e7fff  sprite lookup RAM 1
0d0000-0d1fff  VRAM layer 0      0f8000-0fbfff  work RAM 16 kB
0d2000-0d3fff  VRAM layer 1      0fc000-0fc7ff  sprite RAM 2 kB
0fd000-0fdfff  raster RAM        0fe000-0fe7ff  palette 2 kB

0ff000 r IN0    0ff001 w flip          0ff002 r IN1  w scroll Y 0
0ff004 r DSW    w scroll X 1           0ff006 w scroll Y 1   0ff007 r pending
0ff008 r IN2    0ff008-0ff00b w gfx banks
0ff00e w sound latch                   0ff400-0ff403 w GGA
```

Sprite RAM is split between the chips: chip 0 sees words `0x000-0x1ff`, chip 1 words
`0x200-0x3ff` - each gets a 512-word window with its own `0x1fe` start pointer, exactly like
the single chip in Power Spikes.

## The new mechanism: priority

Power Spikes fills the priority bitmap with 0 and never writes to it again, so its `pri` bit
only chooses which of the two passes a sprite is drawn in. Turbo Force is different:

```cpp
m_tilemap[0]->draw(screen, bitmap, cliprect, 0, 0);   // priority code 0
m_tilemap[1]->draw(screen, bitmap, cliprect, 0, 1);   // priority code 1  <-- writes 1
```

Layer 1 is transparent on pen 15, so it stamps **1** into the priority bitmap only where it has
opaque pixels. Sprites then use `usepri = pri ? 0 : 2`:

- `pri != 0` -> `pmask = 0` -> never masked, draws over everything
- `pri == 0` -> `pmask = 2` -> rejected wherever the bitmap holds 1, i.e. **behind layer 1**

Giving, back to front: **layer 0, sprites with `pri==0`, layer 1, sprites with `pri==1`**.

In HDL that is one extra bit out of the layer-1 pixel (opaque or not) feeding the mixer, plus
the sprite `pri` bit reaching the mixer instead of only ordering the passes. Note the sprite
`pri` bit is currently consumed entirely inside `jtpspike_objscan` - it will have to come out
alongside the pixel.

Chip order is `spr[1]` before `spr[0]`, both passes each.

## Palette

Four fixed blocks of 256, rather than the two banked halves Power Spikes uses:

```
0x000  layer 0    pal = code[15:13]
0x100  layer 1    pal = code[15:13]
0x200  sprites 0  pal = colour[3:0]      (spritepalettebank is never written)
0x300  sprites 1  pal = colour[3:0]
```

So `jtpspike_colmix` needs a per-game index composer. Power Spikes builds
`{charbank, code[15:13]}` and `{1'b1, objbank, colour}`; Turbo Force uses the flat layout above.

## SDRAM - already reserved, nothing moves

The bank map was sized for the whole family at scaffold time, and Turbo Force fits every slot:

| region | size | slot | headroom |
|---|---|---|---|
| maincpu | 0xC0000 | bank 0 @ 0 | exact |
| soundbank | 0x20000 | `SND_START` | exact |
| gfx1 -> scr0 | 0xA0000 | bank 2 @ 0x300000, 1 MB | ok |
| gfx2 -> scr1 | 0xA0000 | `SCR1_START`, 2 MB | ok |
| spritegfx -> obj0 | 0x200000 | bank 3 @ 0x600000, 4 MB | ok |
| gfx4 -> obj1 | 0x80000 | `OBJ1_START`, 2 MB | ok |
| adpcma / adpcmb | 0x100000 / 0x40000 | bank 1 | ok |

## BRAM - this is the cost

Turbo Force needs 136 kB of BRAM on its own. Sharing a build with Power Spikes means the union:

```
work RAM  64 + 16 kB      VRAM      8 + 8 kB
lookup    16 + 16 kB      sprite RAM     2 kB
raster         4 kB       palette        4 kB     = ~138 kB, about 1.1 Mbit
```

Up from ~93 kB today. Fits a Cyclone V, but it is the number to watch, and karatblz later is
worse - its two lookup RAMs are 64 kB **each**.

## Order of work

1. `JTFRAME_VERTICAL` + a game-id in the header (`mame2mra` `[header] registers`), one bit per
   hardware variant. Everything below branches on it.
2. Grow the BRAMs in `mem.yaml`: vram to 8 kB + a second, a second lookup RAM, sprite RAM to
   2 kB, the extra 16 kB work RAM block.
3. `jtpspike_main`: second decoder for the masked 20-bit map, IN2, the 8-bank gfx register,
   two scroll-Y registers.
4. Second `jtpspike_scr` instance. The tile decode differs (11-bit code, 8 banks), and scroll X
   is a single latched value rather than per line - a parameter, not a new module.
5. Second `jtpspike_obj` instance on its own lookup RAM and gfx bus.
6. Mixer: add the layer-1-opaque and sprite-`pri` inputs described above, and the flat palette
   layout.
7. `mame2mra.toml`: drop `mustbe.machines=["pspikes"]`, add the turbofrc region mapping
   (`gfx1`/`gfx2` are the tile layers here, `spritegfx`/`gfx4` the sprites - the opposite of
   what those names mean for pspikes).
8. Capture turbofrc scenes and grade, same harness: `MAMESET=turbofrc`.

## Risks

- **Priority semantics are unverified.** The Power Spikes work established empirically that the
  first sprite written to a pixel wins, which does not match a plain reading of
  `prio_zoom_transpen`. The layer-1 masking above is derived from the same code, so treat it as
  a hypothesis to confirm with scene diffs, not as settled.
- `turbofrc` is missing from MAME 0.276's `-listxml` (`turbofrcj` was not found when
  `doc/mame.xml` was merged) - check the set list before generating MRAs.
- The `rasterram[7]` scroll looks like a driver simplification; the per-row line is commented
  out in the source. Real hardware may well do per-row here too.
