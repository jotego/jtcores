Project files are defined in `cores/<corename>/cfg/files.yaml`.
The `jtframe files` command merges those with framework files and target files.

Command syntax:

`jtframe files <sim|syn|plain> <core-name> [--target target] [--macro A,B,...] [--rel] [--local]`

- `sim` generates simulation file lists
- `syn` generates Quartus assignments
- `plain` generates a plain list of files

Output files:

- game.f for all verilog files
- jtsim_vhdl.f for all VHDL files
- files.qip for synthesis (`syn` mode)
- files for plain text output (`plain` mode)

The `--target` flag also includes:

- `$JTFRAME/target/<target>/cfg/files.yaml`
- `$JTFRAME/target/<target>/cfg/sim.yaml` (only in `sim` mode)

The YAML file is composed of several sections, each of which can only appear once:

- core-name: get files from a given core folder
- module-name: get files from a given folder in modules

# Search rules:

- If only a path is specified, `cfg/files.yaml` in that path is used
- HDL files are looked for in the `hdl` folder
- SDC, QIP files must be in the `syn` folder
- YAML files used to generate more files must be in `cfg`

# File order

The file order is kept in the generated files and it is sometimes important:

- SDC rules can cancel out so the order is important
- VHDL files must be read in a certain order

# Conditional file parsing:

Each file list can be parsed conditionally using the keys:

- unless: will always parse it unless the macro is defined
- when: will only parse it when the macro is defined
