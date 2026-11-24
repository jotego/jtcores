# '88 Games (GX861)

This core reproduces the GX861 board from the three-sheet Konami schematic at
`/gdrive/jotego/arcade/schematics/KONAMI/88 games.pdf`.

The board uses a Konami CPU, Z80 sound CPU, 051961 tile generator, 051960/051962
sprite generator, 051316 zoom layer, YM2151 and sampled speech. The 052606 and
052607 GAL dumps supplied with issue jtcores #128 are the source for CPU address
decoding. The MAME `88games.cpp` driver supplies ROM and input metadata, but its
memory map and layer ordering are not substitutes for schematic wiring.

The core is separate from `aliens` and `ajax` because it combines the former's
tile/sprite hardware and the latter's zoom chip with a distinct CPU map and
sound circuit. Chip RTL can be shared from those cores through `cfg/files.yaml`.

## Sets

- `88games`: world release
- `konami88`: Konami '88
- `hypsptsp`: Hyper Sports Special (Japan)

## Reference material

- GX861 schematic, sheets 1-3
- Decoder GAL dumps and `jedutil` equations in `pal/`
- Board-specific decoder, video, and sound notes in `doc/`
