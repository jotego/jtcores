# jtframe Command Line Tool

JTFRAME cores are not stored as complete Quartus or simulator projects. Instead,
each core keeps a small set of configuration files, mostly under
`cores/<core>/cfg`, and `jtframe` expands them into the concrete files needed by
compilation, simulation, MRA generation, and ROM preparation.

In normal use you usually do not call `jtframe` by hand for every step. The
entry scripts `jtcore` and `jtsim` drive it for you. This document explains
that workflow so it is clear which inputs `jtframe` consumes and which files it
generates.

## Environment and manuals

Run `source setprj.sh` before using the tools. That script defines the
environment expected by `jtframe`, including `JTROOT`, `JTFRAME`, `CORES`, and
`JTBIN`. It also adds JTFRAME man pages to `MANPATH`.

Use these manuals for command-specific detail:

- `man jtframe`
- `man jtframe-<command>` such as `man jtframe-mem` or `man jtframe-files`
- `man jtcore`
- `man jtsim`
- `man jtutil-<command>` when the workflow also uses `jtutil`

## Main inputs from the core

Most core-specific inputs live in `cores/<core>/cfg`:

File          | Purpose
--------------|----------------------------------
`macros.def`    | Target-aware macro definitions used by synthesis, simulation, and MRA flows
`files.yaml`    | Declarative file list for synthesis and simulation
`mem.yaml`      | Memory layout and generator input for SDRAM, BRAM, clocks, audio, and download logic
`mmr.yaml`      | Memory-mapped register description used to generate Verilog modules
`msg`           | Pause/credits text compiled by `jtframe msg`
`mame2mra.toml` | Rules for generating `.mra`, Pocket JSON, and `.rom` related metadata

Not every core uses every file. `jtframe` only runs the relevant generators for
the files that exist.

## Inputs from `$JTFRAME/target`

`jtframe` also consumes target-specific data from `$JTFRAME/target/<target>`.
This is how the framework injects the platform wrapper, pinout, target HDL, and
simulation harness details into a core build.

The important target-side inputs are:

File or folder | Used by
---------------|--------
`$JTFRAME/target/<target>/cfgstr` | `jtframe cfgstr` when producing a target configuration string
`$JTFRAME/target/<target>/<target>.qpf` | `jtframe parse` during synthesis setup
`$JTFRAME/target/<target>/<target>.qsf` | `jtframe parse` during synthesis setup
`$JTFRAME/target/<target>/cfg/files.yaml` | `jtframe files` for target-specific synthesis/simulation files
`$JTFRAME/target/<target>/cfg/sim.yaml` | `jtframe files sim` for simulator-only additions
`$JTFRAME/target/<target>/hdl`, `syn`, `ver` | Referred to by the parsed templates and generated file lists

So `jtframe` does not only read the core's `cfg` folder. It merges core data
with framework and target data to build the final project description.

## Compilation workflow: how `jtcore` uses `jtframe`

The synthesis path is centered on turning declarative core data plus target
templates into a Quartus project in `cores/<core>/<target>`.

These are the main `jtframe` calls made by `jtcore` and `jtcore-funcs`:

1. `jtframe cfgstr <core> --target=<target> --output bash`

   - Parses `cfg/macros.def`, including target-specific sections and command
     line `--def/--undef` overrides.
   - Produces shell assignments that `jtcore` evaluates to obtain values such
     as `CORENAME`, `GAMETOP`, and other derived macros.

2. `jtframe parse <core> $JTFRAME/target/$TARGET/$TARGET.qpf --output ...`
3. `jtframe parse <core> $JTFRAME/target/$TARGET/$TARGET.qsf --output ...`

   - Expands the target templates into a core-specific Quartus project file and
     settings file.
   - The templates come from `$JTFRAME/target/<target>`, while the substitutions
     come from the core macro set.

4. `jtframe cfgstr <core> --target=<target> --output quartus`

   - Appends Quartus-friendly macro assignments to the generated `.qsf`.

5. `jtframe cfgstr <core> --target=<target> --output cfgstr`

   - Resolves the target configuration string, using the target's `cfgstr`
     template plus the core's macros.

6. `jtframe msg <core>` if `cfg/msg` exists

   - Generates message assets used by the pause/credits path.

7. `jtframe mem <core> --target=<target>` if `cfg/mem.yaml` exists

   - Generates the memory-related RTL and include files required by the target
     build.

8. `jtframe mmr <core>` if `cfg/mmr.yaml` exists

   - Generates Verilog modules for memory-mapped registers.

9. `jtframe files syn <core> --target=<target>`

   - Merges `cfg/files.yaml` with JTFRAME and target file lists to create the
     synthesis file list used by Quartus.

After those steps, Quartus sees a normal project with generated `.qpf` and
`.qsf` files, generated RTL from `mem.yaml` and `mmr.yaml`, and a resolved file
list that includes both core files and target/platform files.

## Simulation workflow: how `jtsim` uses `jtframe`

`jtsim` uses the same core configuration files, but it asks `jtframe` for
simulation-oriented outputs in the current simulation folder instead of a target
build folder.

The main `jtframe` calls in `jtsim` and `jtsim-funcs` are:

1. `jtframe cfgstr <core> --target=<target> --output <simulator> > core.def`

   - Produces simulator-specific macro definitions for Verilog tools.

2. `jtframe cfgstr <core> --target=<target> --output cpp > defmacros.h`

   - Produces the C/C++ macro header used by the Verilator test bench.

3. `jtframe cfgstr <core> --target=<target> --output bash`

   - Produces shell assignments that `jtsim` evaluates to recover values such
     as `CORENAME`, `GAMETOP`, SDRAM bank boundaries, and other derived macros.

4. `jtframe mem <core> --target=<target> --local`

   - Generates the memory-derived files in the local simulation area instead of
     the synthesis target folder.

5. `jtframe mmr <core>`

   - Generates memory-mapped register RTL exactly as in synthesis.

6. `jtframe files sim <core> --rel --local --target=<target> --macro ...`

   - Merges `cfg/files.yaml` with JTFRAME files, target files, and
     `target/<target>/cfg/sim.yaml`.
   - Produces the raw simulation file lists that `jtsim` later filters into the
     final `filtered.f`.

7. `jtframe cab <file>.cab` when the user passes `-inputs somefile.cab`

   - Converts cabinet input scripts to `sim_inputs.hex`.

So the simulation flow is not a separate hand-maintained project. It is another
projection of the same core configuration data, with `jtframe` selecting local
outputs and target simulation files.

## ROM and MRA preparation

The MRA flow is related to simulation because `jtsim -setname` eventually needs
a `.rom` file for the selected game set.

`getset.sh`, which is called by `jtsim`, first runs:

`jtframe mra <core>`

That command uses:

- `cores/<core>/cfg/mame2mra.toml`
- `cores/<core>/cfg/macros.def`
- `$JTROOT/doc/mame.xml`
- ROM ZIP files, normally from `~/.mame/roms`

The output is written to the release/ROM area, and `getset.sh` then searches the
generated `.mra` files, extracts the right `.rom`, and creates the default DIP
switch file.

Use:

- `jtframe mra --reduce <path-to-mame.xml>` to rebuild a reduced XML database
- `jtframe mra2rom <file.mra>` when you already have an `.mra` and only want
  the `.rom`

## The practical model

The easiest way to think about `jtframe` is:

- Core `cfg` files describe what the core needs.
- `$JTFRAME/target/<target>` describes how that target wants to wrap and build
  the core.
- `jtframe` combines both descriptions and emits the concrete files needed by
  `jtcore`, `jtsim`, Quartus, and the MRA/ROM tooling.

For day-to-day work, start from `jtcore` and `jtsim`, then open the man page for
the specific generator involved in the step you want to understand in more
detail.
