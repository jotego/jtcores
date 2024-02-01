# Environment variables

Each time you want to work on your project you need to source the file *setprj.sh* from the jtcores folder in your work terminal. By sourcing this file you will get all the expected environment variables, bash functions, etc. that the tool flow needs, such as:

- **JTROOT**, pointing to the folder from where you cloned jtcores
- **CORES**, points to `$JTROOT/cores`
- **JTFRAME**, points to `$JTROOT/modules/jtframe`
- **MODULES**, points to `$JTROOT/modules/modules`

## Folder and File Locations

The cores are compiled using the JTFRAME framework (located in $JTFRAME). It expects a specific folder setup:

Folder   | Path            | Use
---------|-----------------|-----
cores    | $JTROOT         | container for each core folder
foo      | cores           | container for core foo
hdl      | cores/foo       | HDL and include files for core foo
ver      | cores/foo       | verification files. A folder for each test bench
cfg      | cores/foo       | configuration files (macros, RTL generation...)
doc      | cores/foo       | documentation
modules  | modules         | container for each git submodule.
jtframe  | modules/jtframe | JTFRAME repository as a git submodule
rom      | $JTROOT         | Do not add to git. ROM files used for simulation
release  | $JTROOT         | Do not add to git. Mock-up release folder for tests outside JTBIN

### JTBIN

A special git repository for binaries is expected to exist for all JTFRAME based cores. The environment variable **JTBIN** should point to it. Many utilities will store files in it when called with the `--git` option.

Files from JTBIN can be transfered to a SD card or to the MiSTer filesystem by using

- jtbin2mr.sh, copies to a JTBIN folder in MiSTer over ssh
- jtbin2sd.sh, copies to a SD card named MIST or SIDI

These scripts will delete the previous contents of those folders, so a fresh test is possible.

### Macro definition

Macros for each core are defined in a **.def** file. This file is expected to be in the **hdl** folder. The syntax is:

* Each line contains a macro definition, with an optional value after `=`
* A value definition can be concatenated to a previos value by usin `+=` instead of `=`
* Each time a line starts with `[name]`, then a section starts that apply only to the FPGA platform called *name*
* It is possible to include another file by using `include myfile.def`
* `#` marks a comment

Example:

```
include common.def

CPS1
CORENAME=JTCPS1
GAMETOP=jtcps1_game
JTFRAME_CREDITS

CORE_OSD+=;O1,Original filter,Off,On;

[mister]
# OSD options
JTFRAME_ADPCM
JTFRAME_OSD_VOL
JTFRAME_OSD_SND_EN

JTFRAME_AVATARS
JTFRAME_CHEAT
```

Will include the file *common.def*, then define several macros and concatenate more values to those already present in CORE_OSD. Then, only for MiSTer, it will define some extra options

Macros are evaluated with `jtframe cfgstr <corename>`

### Design Source Files

As QIP files are cumbersome and specific to Quartus only, it is possible to bypass them and use a YAML format, like this:

```
game:
  - from: cps1
    get:
      - jtcps1_game.v
      - jtcps1_main.v
      - jtcps1_sound.v
      - common.yaml
jtframe:
  - from: sound
    get:
      - jtframe_uprate2_fir.yaml
      - jtframe_pole.v
modules:
  jt:
    - name: jt51
    - name: jt6295
  other:
    - from: jteeprom/hdl
      get:
      - jt9346.v
```

Each `from` key represents the location to gather the files from and it is combined with the upper key to make the full folder. For instance:

```
game:
  - from: cps1
    get:
    - jtcps1_game.v
```

will get the files `$CORES/cps1/hdl/jtcps1_game.v`

Files from the key `jtframe` are based in folder `$JTFRAME/HDL`. Files from `jt` modules will look directly for a file in `$MODULES/name/hdl/name.yaml`. And files from `other` are based in `$MODULES`

There is also a `target:` section but unless you are creating a new target for JTFRAME, you should not use it. Games cores should not directly reference files in the JTFRAME/target folder. An example of the `target:` section can be seen in [mist](../target/mist/common.yaml).

The utility `jtframe files` translates the yaml files to two files: a game.qip and a target.qip for compilation and a game.f and target.f for simulation. The compilation script [jtcore](../bin/jtcore) calls jtfiles in order to obtain the compilation files.
To get the simulation files call jtfiles as:

`jtframe files sim corename --target mister`

From the folder where you want the files game.f and target.f to be produced.

### Other Configuration Files

The game memory interface can be described in the file mem.yaml, described [here](sdram.md). Using a *mem.yaml* file will generate all the RTL for the SDRAM controller automatically.

The generation of MRA files from MAME's database is done by defining the translation in the file *cfg/mame2mra.toml* and using `jtframe mra <corename>`. This will also generate the PocketFPGA files is the Pocket submodule is available.

The pause screen message is defined in the *cfg/msg* file.