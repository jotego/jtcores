---
name: update JTFRAME target files
description: edition of files in the jtframe/target/* path, including git submodules in that path. commit changes to target folders
---

# Context

JTFRAME is a framework to create FPGA cores of arcade videogame systems. These cores can be compiled for several FPGA platforms. Each platform is called a _JTFRAME target_. The files for these targets live in $JTFRAME/target. Each folder there contains the files for a given FPGA platform. All the folders are part of the jtcores git repository except the `pocket` target, which has its own git repository and is a submodule.

## Pocket Target

When editing `pocket` files, make the edits in the master branch. If a commit is required in the main repository, changes to the `pocket` folder must be committed and pushed first.

## Verification

After editing a target file, a compilation should be triggered to check that the target file integrity has not been altered. Because targets have common files, it is enough to test compilations using the following targets:

- sidi (for changes in sidi, sidi128, mist and neptuno)
- mister
- pocket

Use the `kicker` to test compilations as this core is quick to compile. The compile command is:

`jtcore kicker -target-name -q`

For MiSTer test compilations use:

`jtcore kicker -mister -qq`

because `-qq` excludes the HDMI modules from the test, and hence runs much faster
