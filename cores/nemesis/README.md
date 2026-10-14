# JTNEMESIS — Konami GX400 (Nemesis, 1985)

The GX400 hardware model in this core (main board, sound board, GFX board and
the eight Konami custom ICs) is the work of **LMN-san, OScherler and Raki**,
imported from <https://github.com/GX400-Friends/gx400-src> (GPLv3). Support the
authors: patreon.com/ikamusume · ko-fi.com/lmnsan · ko-fi.com/oscherler

They built it from the Nemesis schematics and verified it against Konami Bubble
System, Salamander and Salamander bootleg PCBs.

## Custom ICs

Name     | Subsystem | Function
---------|-----------|---------
K005924  | Main      | Watchdog / coin operation (not implemented)
K005289  | Audio     | Pre-SCC wavetable sound generator
K005290  | GFX       | Tileline latch
K005291  | GFX       | Tilemap generator
K005292  | GFX       | Video timing generator
K005293  | GFX       | Priority handler
K005294  | GFX       | Sprite latch/MUX
K005295  | GFX       | Sprite engine

## What changed in the JTCORES port

- Top level renamed `nemesis_game` -> `jtnemesis_game` and rewired to the
  current `jtframe_game_ports.inc` interface. The hand-written `jtframe_dwnld` +
  `jtframe_rom_2slots` plumbing is replaced by the `cfg/mem.yaml` generated
  SDRAM interface (`main`, `snd`).
- `jtframe_sh` parameters `width`/`stages` -> `W`/`L`.
- `T80s` port `DO` -> `DOUT` (+ `OUT0` tied low).
- The K005289 volume table is no longer carried by the MRA as a literal blob;
  it is a computed constant, so it ships as `hdl/nemesis_wavvol.hex` and loads
  through `jtframe_prom`'s SIMHEX/SYNHEX. Only the two real 256-byte wave PROMs
  come from the ROM set.
- `nemesis_sound_debug` dropped: it indexed `status[36:32]`, and `status` is
  32-bit now. Its outputs were unconnected anyway.
- The upstream jtframe/jt49 patches are not carried over. Four were cosmetic
  (OSD strings, `-dirty` suffix, git hooks) and one (`jtframe-root-yaml`) is
  moot under the jtcores layout.

### Known deltas from upstream

- **AY volume curve**: upstream patches `jt49` to accept a `JT49_EXP` macro and
  substitutes `nemesis_jt49_exp` (hardware-matched compression, the RC1 audio
  fix). jtcores' `jt49` (nested in the `jt12` submodule) has no such hook, so
  this build uses the stock `jt49_exp`. `hdl/nemesis_jt49_exp.v` is kept out of
  `cfg/files.yaml` until the hook is upstreamed.
- No `bram:` entries in `mem.yaml`: all video RAM lives inside `GX400A_VIDEO`,
  so there is no ioctl save/restore or NVRAM dump yet.
- **No sound.** Boot and video reach the title screen, but the mixer output is
  flat. The Z80 is healthy (out of reset, ~6.9M opcode fetches over 20s of sim);
  the 68000 simply never strobes `/DATA` or `/SOUND_ON`. Look at the main
  address decoder: MAME puts the sound latch at `0x05C001` and the
  outlatch/intlatch pair at `0x05E000-0x05E00F`, split by byte lane
  (`umask16(0xff00)` = outlatch, `umask16(0x00ff)` = intlatch).
