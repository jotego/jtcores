JTFRAME by Jose Tejada (@topapate)
==================================

JTFRAME is a framework for FPGA computing on the MiST and MiSTer platforms. JTFRAME is also a library of verilog modules, including simulation models and utilities to develop retro hardware on FPGA.

All JT FPGA cores follow the JTFRAME methodology fully. Other developers either use most of it adapted to work in Ms Windows or just take individual files without using the JTFRAME design approach. Whatever you find useful is fine as long as you follow the GPLv3 license.

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# Topics

## Basic Concepts
* [Folder setup](doc/folders.md)
* [Compilation](doc/compilation.md)
* [The command line tool jtframe](doc/jtframe.md)
* [Simulation](doc/sim.md)
* [Unit tests](doc/simunit.md)
* [Version history](doc/version.md)

## More Details
* [MiST derivatives](doc/mist.md)
* [CPUs](doc/cpus.md)
* [SDRAM and SD card](doc/sdram.md)
* [The MOD Byte](doc/core_mod.md)
* [The OSD](doc/osd.md)
* [Clocking](doc/clocks.md)
* [Video options](doc/video.md)
* [Audio filters](doc/audio.md)
* [User inputs](doc/inputs.md)
* [The credit screen](doc/credits.md)
* [Compilation macros](doc/macros.md)
* [IP reference](doc/ip.md)
* [Style guidelnes](doc/style.md)

## Private Support Files

Set `JOTEGO` to the private support-files directory used by JTCORES regressions and scene data. Generic scene simulations store their data in `$JOTEGO/scenes/<core-name>/<set-name>`.

When `jtsim -s <scene>` runs from `cores/<core-name>/ver/<set-name>`, it requires `JOTEGO` and creates the local `scenes` symbolic link to that private scene directory.

## Target Specific
* [Pocket](target/pocket/README.md)
* [MiSTer](target/mister/README.md)

## Advanced Topics
* [Debug features](doc/debug.md)
* [Cheat subsystem](doc/cheat.md)

## Check Lists
* [Debug checklist](doc/debug_list.md)

# Licensing

Contact the author for special licensing needs. Otherwise follow the GPLv3 license attached.
