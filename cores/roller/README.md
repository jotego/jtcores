# Roller Games (GX999)

This core targets the Roller Games PCB documented in `sch/`. The KiCad
schematics and decoded F11/F12 GAL equations in `pal/` define the hardware.
The MAME `rollerg.cpp` driver in `doc/` supplies ROM and input metadata.

The main CPU is the Konami 053248. Video consists of a zoom layer implemented
with discrete logic in the schematic and a 053244/053245 sprite pair. The
sound board has a Z80, YM3812 and 053260.

## Main CPU decoding

`jtroller_decode` implements F11 (053758) and F12 (053759). Pin numbers and
net names come from the KiCad netlist. F11 input pins 1-9 are `/AS`, A15, A14,
A13, A12, A19, A18, A17 and A16. F11 pin 12 feeds F12 pin 1. F12 pin 2 is
G18 pin 7; pins 3-9 are A12-A6. Its pin 11 (A5) has no fitted product term.

| F11 pin | Net | Result |
| --- | --- | --- |
| 12 | F12 pin 1 | Low at 0000-1fff during `/AS` |
| 13 | `~CS1` | Low at 2000-3fff during `/AS` |
| 14-17 | `MAIN_AB0` to `MAIN_AB3` | ROM bank address bits |
| 18 | F9 `/OE` | Low for CPU data buffer at 0000-3fff |
| 19 | `OOE` | Low for ROM at 4000-ffff |

F11 pin 19 is configured active high in the GAL fuse map; pins 12-18 are
active low. F12 outputs select 0000/0400, 0100/0500, 0200/0600,
0300/0700, 0800-0fff, 1000-17ff and 1800-1fff. F12 pins 16 and 17 split
0800-0fff according to G18 pin 7.

`pal/Konami_053758.txt` and `pal/Konami_053759.txt` contain the pin modes and
equations produced by `jedutil -view <file.jed> GAL16V8` from the supplied
JED files. The JED files are not part of the repository.
`simunit-all.sh --only jtroller_decode` checks
representative decoder boundaries and the active-low bus qualification.

## Object ROM reads

The 053244 exposes the sprite ROM to the main CPU at registers C-F. Writes to
registers 8, 9 and B select a 32-bit word; C-F select its XOR-one byte lanes.
`jtriders_obj` presents that word address to SDRAM and keeps the CPU waiting
until `obj_ok` is asserted. `simunit-all.sh --only jtriders_obj` checks the register
address, all four byte lanes and the wait signal without running the lengthy
service-mode ROM check.
`ver/rollerg/service.cab` reproduces the full check by enabling the service
DIP at boot and holding 1P from frame 900 through the transition to the OBJ
check. The K2 result appears before K8; both report OK by frame 3350 in the
full simulation.

## Flip screen

The Flip Screen DIP is read at boot. It changes both the 051316 zoom matrix
and the 053244 global flip and offset registers. Flipped scene captures must
boot MAME with the DIP enabled; changing it after boot only updates part of
the video state. GX999 needs the 053244 horizontal and vertical flip offsets
set in `jtroller_video` to align sprites with the zoom layer. The core's raw
video remains the horizontal 288 x 224 raster specified by MAME (`ROT0`).

## Scene captures

The shared `~/mame/scene` worktree can capture Roller Games frames with
`-dump_scenes 1000,2000,3000,4000,5000,6000 -jtcore_path $JTROOT/cores/roller`.
Each `dump.bin` contains the palette, 051316 RAM, buffered 053245 sprite RAM,
051316 registers, 053244 registers, 053252 registers, and external enable
latch in that order. `mem.yaml` extracts the palette into BRAM; `ver/rest2bin.sh`
splits the remaining bytes for `jtsim -s`. Run `jtutil sdram` in
`ver/rollerg` before scene simulations to create the SDRAM bank files.
