# jtframe Command Line Tool

JTFRAME cores have code generated from configuration files in `cores/<core>/cfg`.

File          | Purpose
--------------|----------------------------------
macros.def    | Verilog macros are defined here
files.yaml    | List of files required to synthesize or simulate the core
mame2mra.toml | Defines the conversion from MAME's database to MRA and Pocket files
mem.yaml      | RTL generator for the SDRAM interface
msg           | Message displayed by _jtframe_credits_

The `jtcore` and `jtsim` scripts call `jtframe` commands as part of normal build and simulation flows.

`jtframe mra <corename>` uses `$JTROOT/doc/mame.xml` by default.  
Use `jtframe mra --reduce <path-to-mame.xml>` to regenerate a reduced XML file for JT cores.

`jtframe` requires these environment variables to be set: `JTROOT`, `JTFRAME`, `CORES`, `JTBIN`.

Main subcommands currently provided by the Go CLI are:

- `cab`
- `cfgstr`
- `files`
- `mem`
- `mmr`
- `mra`
- `mra2rom`
- `msg`
- `parse`
- `sch`
- `ucode`
- `update`

`jtutil` is a separate utility collection for development workflows.
