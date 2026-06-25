# jt05415x Verilog Implementatin of K054126-K054157 Pair

The K054126-K054157 chips work as a pair and are used to generate the tile map layers on several Konami games.

These two chips have been reverse engineered into two schematic by Furrtek. The RE-ed schematics can be located in `/nobackup/jtmisc/reverse/SiliconRE/Konami/054156` and `/nobackup/jtmisc/reverse/SiliconRE/Konami/054157`.

The two schematics have been converted to verilog as a single file in:

- `doc/054156/jt054156_all.v`
- `doc/054157/jt054157_all.v`

There is an implementation of these chips in C++ in `doc/mame/`. But this implementation is imperfect as it is based on interpreting what the game software does and what the actual game seems to do in reaction. So the C++ version is roughly right, but it will surely be missing plenty of details.

The current mapping between the MAME registers and the extracted HDL registers
is documented in `doc/register_map.md`.
