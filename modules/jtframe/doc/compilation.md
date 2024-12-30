# Compilation

All JT arcade cores depend on JTFRAME for compilation. You need to follow the jtframe framework in order to compile and simulate these cores.

## Prerequisites

- Ubuntu 20.04
- Install Quartus 13.1 to compile for MiST, SiDi and the Pocket in `/opt/altera/13.1`
- Install Quartus 17 or higher to compile for MiSTer in `/opt/intelFPGA_lite`
- Run the [../bin/jotego_20.04.sh](jotego_20.04.sh) script to get other required packages in place

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
* There are some linux dependencies that you can sort out with `sudo apt install`, mostly Python, the pypng pythong package, Go and the YAML.v2 package
* Populate the arcade core repository including submodules recursively. I believe in using submodules to break up tasks and sometimes submodules may have their own submodules. So be sure to populate the repository recursively. Be sure to understand how git submodules work
* Now jtframe should be located in `core-folder/modules/jtframe` go there and enter the `cc` folder. Run `make`. Make sure all files compile correctly and install whatever you need to make them compile. All should be in your standard linux software repository. Nothing fancy is needed
* Now go to the `core-folder` and run `source setprj.sh`
* Now you can compile the core using the `jtcore` script.

The output file is stored in **releases/target** where target stands for the FPGA platform (mist, mister, etc.). Most platforms use files with a .rbf extension, but some use a different extension -though the underlying file type is the same.

## jtcore

jtcore is the script used to compile the cores. It does a lot of stuff and it does it very well. Taking as an example the [CPS0 games](https://github.com/jotego/jtcores), these are some commands:

`jtcore gng -sidi`

Compiles Ghosts'n Goblins core for SiDi.

`jtcore tora -mister`

Compiles Tiger Road core for MiSTer.

Run `jtcore -h` to get help on the commands.

jtcore can also program the FPGA (MiST or MiSTer) with the ```-p``` option. In order to use an USB Blaster cable in Ubuntu you need to setup two urules files. The script **jtblaster** does that for you.

## jtupdate

To compile all cores in a JTFRAME project, run

`jtupdate --target mister`

The output will be created in $JTROOT/release. See `jtupdate -h` for more details.

## Release procedure

Release builds are produced by a GitHub action for all FPGA platforms supported. The GH action produces a zip file that is automatically stored in a Google Drive folder. You can also download the zip file manually from the [GH action log](https://github.com/jotego/jtcores/actions/workflows/daily.yaml). The zip uses the git hash as the name.

Once downloaded, execute `jtrelease.sh hash` to copy the release. A environment variable called JTBUILDS can be defined and export. Builds will be searched for in the path set by JTBUILDS.

`jtrelease.sh` produces the necessary files in JTBIN and leaves JTBIN in a new branch, ready to be merged and pushed, which must be done manually as a final check. The script also runs `cpbeta.sh`, which creates zip files for each FPGA platform and copies them to the path pointed to by the environment variable JTFRIDAY.