The project files are defined in cores/corename/files.yaml.
jtframe files command will also add the required files for the
selected compilation or simulation target.

The first argument selects simulation (sim) or synthesis (output). The
synthesis output consists of .qip files compatible with Intel Quartus.

A third option is "plain", which simply generates a plain text file with
the file names and path used.

The simulation output creates two files:

- game.f for all verilog files
- jtsim_vhdl.f for all VHDL files

For synthesis a `files.qip` is generated at the core/target folder.

The yaml file is composed of several sections, which can only appear once:

- core-name: get files from a given core folder
- module-name: get files from a give folder in modules

# Search rules:

- If only a path is specified, the files cfg/files.yaml in it is looked for and
used
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