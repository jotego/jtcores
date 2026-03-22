---
name: Questions about the CPS3 hardware and CPS3 documentation update
description: Read the current cps3/doc/gfx.md and the MAME implementation to answer questions about the CPS3 hardware. Update the file $JTROOT/cores/cps3/doc/gfx.md if inconsistencies or more information is needed.
---

- The MAME repository is at $JTROOT/../mame
- The cps3.cpp file in MAME (src/mame/capcom/cps3.cpp) contains the CPS3 driver
- cps3.cpp is part of the MAME emulator, so reading other MAME files may be
needed to understand how cps3.cpp implements the system
- The $JTROOT/cores/cps3/doc/gfx.md is meant to work as a reference to guide
the new FPGA core implementation of the cps3 as the new JTCPS3 core, part of
the jtcores project
- The file $JTROOT/cores/cps3/cfg/mmr.yaml contains the PPU registers and it should
be updated with relevant comments. The gfx.md file can use the name of the
registers in mmr.yaml
- gfx.md should contain clear references to the MAME source code to sustain
its claims