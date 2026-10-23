# Compilation

All JT arcade cores depend on JTFRAME for compilation. You need to follow the jtframe framework in order to compile and simulate these cores.

## Prerequisites

- Ubuntu 20.04
- Install Quartus 13.1 to compile for MiST, SiDi and the Pocket in `/opt/altera/13.1`
- Install Quartus 17 or higher to compile for MiSTer in `/opt/intelFPGA_lite`
- Run [`../bin/install/jotego_20.04.sh`](../bin/install/jotego_20.04.sh) to install the expected packages

For parallel compilation across network machines, create a file `$HOME/.parallel/sshloginfile` with one host name per line. Configure SSH correctly across the machines, using `ssh-copy-id`, etc.

JTFRAME uses a submodule to give support to the *Analogue Pocket* target. This submodule is not open source and you will get an error if you try to initialize it. You can safely ignore this submodule, it is only needed to create Pocket files.

## Quick Steps

These are the minimum compilation steps, using _Pirate Ship Higemaru_ as the example core

```
> git clone --recursive https://github.com/jotego/jtcores
> cd jtcores
> source setprj.sh
> jtframe
> jtcore hige
```

That should produce the MiST output. If you have a fresh linux installation, you probably need to install more programs. These are the compilation steps in more detail

* You need linux. I use Ubuntu mate but any linux will work
* You need 32-bit support if you're going to compile MiST/SiDi cores
* There are some Linux dependencies that you can sort out with `sudo apt install`, mostly Python, the `pypng` Python package, Go and the YAML.v2 package
* Populate the arcade core repository including submodules recursively. I believe in using submodules to break up tasks and sometimes submodules may have their own submodules. So be sure to populate the repository recursively. Be sure to understand how git submodules work
* Now jtframe should be located in `core-folder/modules/jtframe` go there and enter the `cc` folder. Run `make`. Make sure all files compile correctly and install whatever you need to make them compile. All should be in your standard linux software repository. Nothing fancy is needed
* Now go to the `core-folder` and run `source setprj.sh`
* Now you can compile the core using the `jtcore` script.

The default output root is `$JTROOT/release` (for example `$JTROOT/release/mister` or `$JTROOT/release/mist`). Most platforms use files with a `.rbf` extension, but some use a different extension even though the underlying type is equivalent.

## jtcore

jtcore is the script used to compile the cores. It does a lot of stuff and it does it very well. Taking as an example the [CPS0 games](https://github.com/jotego/jtcores), these are some commands:

`jtcore gng -sidi`

Compiles Ghosts'n Goblins core for SiDi.

`jtcore tora -mister`

Compiles Tiger Road core for MiSTer.

Run `jtcore -h` to get help on the commands.

### Reusing compilation results

`jtcore` keeps the target directory and Quartus databases between builds. The
first build establishes the fitted database. Subsequent builds with matching
settings attempt Rapid Recompile, which can preserve placement and routing
after small RTL changes. If Rapid Recompile fails, `jtcore` saves its log as
`*.rapid.log` and retries the ordinary full compilation flow using the retained
databases. Unsupported editions or devices are remembered until the compiler
selection changes or the cache is cleaned.

```bash
jtcore cps3 -mr --nodbg          # establish the database, then reuse it
jtcore cps3 -mr --nodbg --clean  # discard the cache and start a full build
jtcore cps3 -mr --nodbg --incremental # keep explicit design partitions
```

`--rapid` selects the default automatic Rapid Recompile flow again, for example
when overriding `--incremental` in `JTCORE_DEFAULT`. Rapid Recompile requires a
compatible Quartus edition and device. Projects with explicit child partitions
use ordinary incremental compilation; the framework's default Top partition is
removed from flat projects prepared for Rapid Recompile. MiST builds use the
ordinary incremental flow.

Changing the compiler, seed, macros, generated file list, or QSF settings selects
ordinary full compilation to refresh the database. Shared module and core
constraint, Tcl, QIP, INI, and IP configuration files are also fingerprinted.
Reordering the same generated file-list assignments does not invalidate reuse.
Quartus checks RTL changes as part of its compilation flow. A failed compilation cannot
mark a database reusable or publish an old bitstream. Timing acceptance is still
checked on every build, including Rapid Recompile builds.
Preserved placement can give different timing results from a full build. If a
Rapid Recompile build fails timing, use `--clean` to rerun full optimization.

The generated `JTFRAME_TIMESTAMP` is kept for the lifetime of the cache so an
automatically changing macro does not invalidate every build. Explicit command
line timestamp definitions are respected. Use `--clean` to refresh the timestamp
and produce a fresh release build. Simulation builds still start from a clean
directory.

Use `jtcore <core> --signaltap` to enable SignalTap when the core provides
`cores/<core>/syn/signaltap.qsf`. A core may also opt in by defining
`JTFRAME_SIGNALTAP` in `cfg/macros.def`. The generated target QSF keeps
SignalTap disabled unless one of those two mechanisms is used.

jtcore can also program the FPGA (MiST or MiSTer) with the ```-p``` option. In order to use a USB Blaster cable in Ubuntu you need to set up two udev rules files. The script **jtblaster** does that for you.

## jtupdate

To compile all cores in a JTFRAME project, run

`jtupdate --target mister`

The output will be created in $JTROOT/release. See `jtupdate -h` for more details.

## Release procedure

Release builds are produced by a GitHub action for all FPGA platforms supported. The GH action produces a zip file that is automatically stored in a Google Drive folder. You can also download the zip file manually from the [GH action log](https://github.com/jotego/jtcores/actions/workflows/daily.yaml). The zip uses the git hash as the name.

Once downloaded, execute `jtrelease.sh hash` to copy the release. A environment variable called JTBUILDS can be defined and export. Builds will be searched for in the path set by JTBUILDS.

`jtrelease.sh` produces the necessary files in JTBIN and leaves JTBIN in a new branch, ready to be merged and pushed, which must be done manually as a final check. The script also runs `cpbeta.sh`, which creates zip files for each FPGA platform and copies them to the path pointed to by the environment variable JTFRIDAY.
