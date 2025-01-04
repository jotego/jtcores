# jtframe Command Line Tool

JTFRAME cores have code generated from several configuration files in the core's cfg folder.

File          | Purpose
--------------|----------------------------------
macros.def    | Verilog macros are defined here
files.yaml    | List of files required to synthesize or simulate the core
mame2mra.toml | Defines the conversion from MAME's database to MRA and Pocket files
mem.yaml      | RTL generator for the SDRAM interface
msg           | Message displayed by _jtframe_credits_

The *jtcore* and *jtsim* utilities are designed around these files and will produce the right output without any direct intervention. They parsed the files using the required calls to the _jtframe_ CLI or other required programs.

For the MAME-to-MRA conversion, you need to invoke directly `jtframe mra <corename>` from the $ROM folder. The tool expects a dump from the MAME database in $ROM/mame.xml.

`jtframe` generates files needed for compilation and simulation. `jtutil` is a collection of tools that help during development, but are not needed for compilation.
