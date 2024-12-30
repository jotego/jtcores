# MiSTer Target

This target is maintained by Jose Tejada

## MiSTer-Specific Macros

Use **MISTER_EXTRA** to add [non-OSD options](https://github.com/MiSTer-devel/Wiki_MiSTer/wiki/Core-configuration-string#non-osd-options-must-be-placed-at-bottom-of-configuration-string) to the config string. This is useful for defining the gamepad on console cores that may be loaded without an MRA file.

## Useful Links

MiSTer has a linux subsystem running on an ARM9 called the _Hard Processor System_ (the HPS). Communication with it is done using the Intel's Avalon interface.

- [Cyclone V Hard Processor System Technical Reference](https://www.intel.com/content/www/us/en/docs/programmable/683126/21-2/hard-processor-system-technical-reference.html)
- [Avalon Interface Specifications](https://www.intel.com/content/www/us/en/docs/programmable/683091/20-1/introduction-to-the-interface-specifications.html)