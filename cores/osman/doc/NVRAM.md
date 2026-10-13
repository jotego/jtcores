# EEPROM defaults and saved settings

The Osman core models a 93C46 EEPROM: **64 words of 16 bits, 128 bytes total**.
Region, button configuration, bookkeeping and service-menu settings live here.
Osman and Cannon Dancer require valid defaults to boot and use different EEPROM
images despite sharing their game ROMs.

## MiSTer boot and save sequence

1. The MRA downloads the game ROM and its family header at index 0.
2. `<rom index="2">` downloads the selected set's EEPROM defaults.
3. `<nvram index="2" size="128"/>` tells MiSTer to restore an existing saved
   image, if present. This transfer overwrites the defaults. With no saved image,
   MiSTer keeps the defaults; it does not send a blank replacement.
4. The ARM stays in reset during each EEPROM restore until the last word write
   has committed. The game then starts with the resulting settings.
5. Select **Save settings** in the MiSTer OSD after changing settings. MiSTer
   uploads the current 128 EEPROM bytes at index 2 and writes the `.nvm` file.
   The ARM stalls during this upload and resumes afterwards.

Loading is automatic. **Writing EEPROM cells in the game does not automatically
save them to the SD card.** This core uses JTFRAME's normal arcade NVRAM path;
it does not request background uploads or use the virtual-SD `JTFRAME_SAVEGAME`
interface. Save before switching cores or powering off.

MiSTer names the save after the **MRA filename**, replacing `.mra` with `.nvm`,
under `config/nvram/` on its storage root. For example:

```text
config/nvram/Osman (World).nvm
config/nvram/Cannon Dancer (Japan).nvm
```

To return to ROM-set defaults, back up and remove the matching save, then reload
the MRA. A soft reset preserves EEPROM contents and does not reload defaults.
Keep both the new RBF and regenerated MRA when installing this change.
Saves produced by the previous broken loader may already contain corrupted
words; back them up and recreate the settings if they still prevent boot.

The firmware implementation is in MiSTer Main's
[MRA loader](https://github.com/MiSTer-devel/Main_MiSTer/blob/master/support/arcade/mra_loader.cpp)
(`arcade_nvm_load`, `arcade_nvm_save`, and the closing `nvram` element handler).

## Where defaults come from

`cfg/macros.def` declares `JTFRAME_IOCTL_RD=128`. JTFRAME's MRA generator uses
that size to emit the `nvram` element. `cfg/mame2mra.toml` renames MAME's
`eeprom` region to `nvram`, excluding it from the main index-0 ROM image and
emitting its filename and CRC in the separate index-2 ROM section.

| Sets / family | First-boot contents | Bytes in MRA / MiSTer save |
| --- | --- | --- |
| Osman | `eeprom-osman.bin` from ROM ZIP | High byte, then low byte |
| Cannon Dancer | `eeprom-candance.bin` from clone or merged parent ZIP | High, low |
| Chain Reaction | `eeprom-chainrec.bin` from ROM ZIP | High, low |
| Magical Drop | `93c45.2h` from ROM ZIP | Low, high |
| Magical Drop Plus | `eeprom.2h` from ROM ZIP | Low, high |
| Party Time / Ganbare! Gonta!! | Their respective EEPROM ROM dumps | High, low |
| Joe & Mac Returns, Charlie Ninja, Heavy Smash and their supported clones | 128 `FF` bytes from TOML: erased EEPROM, matching MAME when no EEPROM region exists | All erased words are `FFFF` |

Magical Drop's two sets use MAME's `ROM_LOAD16_WORD_SWAP`. The `md` / `mdp`
header bits select the matching byte swap in `jtosman_eeprom` for **both**
download and upload. Save files therefore retain the same byte order as each
set's original ROM dump. No preprocessing or replacement ROM ZIP is needed.

JTFRAME's default-source priority is: `cfg/<set>.nvm` (then parent `.nvm`),
TOML `nvram.defaults`, then the ROM region. Avoid local `.nvm` overrides for
sets with ROM defaults unless intentional: a parent override can also replace a
clone's region settings. These files are ignored by Git and do not accompany a
clean checkout. The tracked TOML covers erased defaults; the ROM ZIP covers the
other sets.

## HDL wiring

`jtosman_game` forwards `ioctl_addr`, `ioctl_dout`, `ioctl_wr`, `ioctl_ram` and
`ioctl_din` to `jtosman_main`, which instantiates `jtosman_eeprom`.

`jtosman_eeprom` uses the **native 16-bit dump port of `jt9346`**. The first
byte is buffered; receipt of its matching second byte schedules one word write
with a latched address. The final write completes even if the transfer ends or
the bus address changes immediately afterwards. Uploads read this same EEPROM
RAM through its synchronous dump port, with the byte selector delayed to match
the RAM read. Addresses outside 0–127 are excluded from writes.

The EEPROM has no second backing RAM in `cfg/mem.yaml`. A background mirror
would introduce a second copy that could overwrite a newly downloaded default
or lag behind a game write. `JTFRAME_IOCTL_RD` remains necessary even though
there is no `mem.yaml` NVRAM block: memgen routes `ioctl_din` directly from the
game module when there are no generated BRAM dump sections.

Index-2 downloads set `ioctl_ram` and `ioctl_wr`; they do **not** set the
game-ROM `ioctl_rom` signal. The adapter detects the actual EEPROM writes and
holds the ARM and serial protocol in reset for that restore. Uploads set
`ioctl_ram` without writes, so they stall the ARM without resetting it.
The EEPROM RAM itself is never cleared by soft reset.

The old hardcoded `eeprom_osman.hex` loader and the byte-scanning mirror are
replaced by this path. Inverting the byte address on `jt9346_16b8b` was insufficient:
that wrapper commits a word when its high-byte address is written, so streaming
big-endian pairs could commit before the corresponding low byte arrived.

## Regeneration and simulation

With the normal JTCORES environment, regenerate with:

```bash
jtframe mra osman --skipPocket --path "$HOME/.mame/roms-local"
```

On this macOS checkout, the native binary is `modules/jtframe/bin/jtframemac`.
It requires absolute project environment paths; from the repository root:

```bash
export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe"
export CORES="$PWD/cores" MODULES="$PWD/modules" JTBIN="$PWD/release"
"$JTFRAME/bin/jtframemac" mra osman --skipPocket --path "$HOME/.mame/roms-local"
```

Before boot simulation, prepare exactly the image described by the generated
MRA, including clone ZIP fallback and EEPROM CRC checks:

```bash
bash cores/osman/ver/prepare_nvram.sh osman
```

The helper writes `ver/game/nvram.seed`. `rest2bin.sh --delete`, called by jtsim's
existing cleanup hook, copies it to `nvram.bin`; the standard Verilator harness
downloads that file through the same EEPROM ioctl interface as MiSTer.
Run jtsim in the simulator environment with **`-load`**:

```bash
cd cores/osman/ver/game
jtsim -setname osman -load -video 24 -d JT9346_SIMULATION
```

For full boot acceptance, run the CPU, video and sound together from power-on
defaults and inspect the opening/title/attract captures, without scene replay or
test-switch inputs:

```bash
FRAMES=3000 bash cores/osman/ver/attract_run.sh magdrop
FRAMES=1200 bash cores/osman/ver/attract_run.sh charlien
```

The helper archives captures and logs under `ver/<set>/sim_results/attract/`.
Magical Drop stays on its normal Japan warning screen beyond 1,200 game frames
in MAME too; use the longer run to reach its animated opening and tutorial.
An initial CPU trace match alone does not establish a completed boot.
Charlie Ninja's erased-default full run reached its complete title and
`INSERT COIN` screen after 1,200 game frames without service/test inputs. Its
striped pink transition is also present in MAME and is part of the intro.
Magical Drop's extended ROM-default run reached the Data East opening, animated
characters, complete title and running tutorial. These full boot captures,
rather than an initial PC trace, validate normal startup past the EEPROM check.
That run completed 2,600 game frames; its live 128-byte EEPROM upload matched
the ROM-set defaults exactly.

The cached-ROM shortcut skips the NVRAM transfer. Always use `-load` for a fresh
boot with these defaults. `boot_check.sh` and `attract_run.sh` prepare the image
and enforce this flag for every selected set. Full loading adds simulated frames
before the requested game frames.

To test a MiSTer saved image instead of defaults:

```bash
NVRAM_FILE='/path/to/Osman (World).nvm' bash cores/osman/ver/prepare_nvram.sh osman
```

`ROMS_HOST` accepts colon-separated ROM paths; `MRA_DIR` selects a different
generated MRA folder. The helper rejects missing/wrong-CRC ROM parts and images
other than 128 bytes. A MAME live `nvram/<set>/eeprom` file is a different format:
MAME serializes its internal words little-endian, so do not substitute it directly
for a MiSTer save on the high-byte-first families.

After an ioctl dump, `dump2bin.sh` passes the direct game dump in `rest.bin`;
`rest2bin.sh` recognizes the 128-byte EEPROM image and copies it to `nvram.bin`.
It also preserves the existing `0x5810`-byte video scene layout, splitting its
palette, playfield, rowscroll and sprite RAM while leaving control registers in
`rest.bin`. To retain an uploaded EEPROM image for another run, copy it to
`nvram.seed` before jtsim cleanup.

## Validation and troubleshooting

Run the standalone EEPROM regression with Icarus Verilog:

```bash
bash cores/osman/ver/eeprom/run.sh
```

It checks Osman boot words `FFBE` / `0088`, all 64 serial words, saved-image
replacement without global reset, consecutive byte writes including the final
word, immediate upload after serial writes, reset persistence, both byte orders,
and exclusion of ROM/out-of-range writes. Full-core Verilator checks are also
required after changing the game ports or configuration.

Verified for this implementation: EEPROM regression passed, full-core Verilator
lint/compilation passed with existing warnings, and Osman / Cannon Dancer each
completed a full ROM/NVRAM download plus 24 game frames. Both 128-byte ioctl
uploads matched their own ROM-set defaults byte-for-byte; serial reads returned
`FFBE` (Osman) and `FFBF` (Cannon Dancer), with word `20` equal to `0088`.
Both ARM traces matched the 1,600-PC MAME boot reference. Default preparation
also succeeded for all 13 supported sets, and a short saved image was rejected.

If a game boots with the wrong region, check its generated index-2 ROM part,
local `cfg/*.nvm` overrides and existing MiSTer save. If settings disappear after
power-off, use **Save settings** and verify the matching 128-byte file in
`config/nvram/`. If a simulation starts with erased or previous-set contents,
regenerate the MRA, prepare the seed for the selected set and use `-load`.
FPGA hardware boot and SD-card persistence must still be checked on MiSTer after
rebuilding; the regression cannot exercise the physical HPS/SD connection.
