The project files are defined in cores/corename/game.yaml.
jtframe files command will also add the required files for the
selected compilation or simulation target.

The first argument selects simulation (sim) or synthesis (output). The
synthesis output consists of .qip files compatible with Intel Quartus.

A third option is "plain", which simply generates a plain text file with
the file names and path used.

The simulation output creates two files:
- game.f for all verilog files
- jtsim_vhdl.f for all VHDL files

The yaml file is composed of several sections, which can only appear once:

- game: get files from a given core hdl folder
- jtframe: get files from jtframe/hdl folders
- modules: get files from the modules folder

For modules, there is a shortcut for JT ones and a generic way

modules:
  jt:
    - name: jt51
      when: MACRO name
    - name: jtkcpu
      unless: MACRO name
  other:
  	- from: foo
  	  get: [ hdl/foo.v ]

# Conditional file parsing:

Each file list can be parsed conditionally using the keys:
- unless: will always parse it unless the macro is defined
- when: will only parse it when the macro is defined