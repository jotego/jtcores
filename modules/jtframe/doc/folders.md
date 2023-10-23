# Folder Setup

JTFRAME projects require a specific folder and git usage so the tool flow works correctly. Examine some JT cores using it to see an example (like [JTKICKER](https://github.com/jotego/jtkicker)). This section covers a few concepts about JTFRAME's folder structure.

## Using Git Submodules In Your Project

JTFRAME is built around the idea of modular projects that facilitate reuse: jtframe for the general framework, jt51 for YM2151 sound, jtopl for OPL sound, etc. The best way to do this in a git project is to use git submodules.

To start a new JTFRAME project, start by making an empty git project. And then:

1. Optionally fork JTFRAME's repository to your own GitHub account
2. Add it as a submodule to your git project in the modules folder:
```
mkdir modules
cd modules
git submodule add https://github.com/jotego/jtframe.git
```
3. Now you can refer to the RTL files in **jtframe/hdl**

The advantages of a using a git submodule are:

1. Your project contains a reference to a commit of the JTFRAME repository
2. As long as you do not manually update the JTFRAME submodule, it will keep pointing to the same commit
3. Each time you make a commit in your project, it will include a pointer to the JTFRAME commit used. So you will always know the JTFRAME that worked for you
4. If JTFRAME is updated and you want to get the changes, simply update the submodule using git. The new JTFRAME commit used will be annotated in your project's next commit. So the history of your project will reflect that change too.
5. JTFRAME files will be intact and you will use the files without altering them.

Each time you want to work on your project you need to source the file in *modules/jtframe/bin/setprj.sh* from your work terminal. JT cores have a file conveniently called *setprj.sh* at the root of the project that sources it and may add some core-specific setup. By sourcing this file you will get all the expected environment variables, bash functions, etc. that the tool flow needs.

## Folder and File Locations

JTFRAME expects a specific environment. The following folders should exist:

Folder   | Path            | Use
---------|-----------------|-----
cores    | root            | container for each core folder
foo      | cores           | container for core foo
hdl      | cores/foo       | HDL and include files for core foo
ver      | cores/foo       | verification files. A folder for each test bench
cfg      | cores/foo       | configuration files (macros, RTL generation...)
doc      | cores/foo       | documentation
rom      | root            | ROM files used for simulation
release  | root            | Do not add to git. Mock-up release folder for tests outside JTBIN
modules  | modules         | container for each git submodule.
jtframe  | modules/jtframe | JTFRAME repository as a git submodule

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