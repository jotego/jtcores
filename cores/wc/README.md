# Grid Iron

# Test Mode

- Hold 1P and 2P while resetting the machine to enter test mode
- Hold shot button to keep the grid on display. Press again to continue

# Simulation Notes

| Simulation              | Command                   |
|:------------------------|:--------------------------|
| Grid image              | `jtsim -w 270 -video 296` |
| Start of subsidiary CPU | `jtsim -w -video 30`      |

# PCB Notes

The schematic extraction was done from a bootleg board, but it was carefully compared with an original one. These are the differences:

- original PCB has through-hole vias whereas the bootleg has filled vias
- original uses three custom packages from Mitsubishi with logic inside. These were replaced by a small daughter board on the bootleg, serving the same functionality
- different edge connectors
- debug edge connector on video board not present on bootleg
- cabinet input logic partly missing and rewired on the bootleg to replace the trackball interface for a joystick one
- different power amplifier for sound without heat sink on the bootleg
- slightly different frequencies for crystal oscillators (cost reduction?)
- device reference markers (silkscreen) on bootleg have reversed order on bootleg

Note that the schematic passes KiCAD electrical rule check with zero errors.