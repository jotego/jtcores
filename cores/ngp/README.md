# NeoGeo Pocket Compatible FPGA core by Jotego

Please support the project
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# System Details

| unit    | memory (kB) | remarks        |
|:--------|:------------|:---------------|
| T800H   | 12+4        | upper 4 shared |
| Z80     |  4          | shared         |
| Fix     |  8          |                |
| Scroll  |  4          | 2kB per layer  |
| Objects |   .25       |                |
| Total   | 32          |                |

- Is the video chip connection to the data bus 16 or 8 bits?
- Palette RAM is 16-bit access only and has no wait states

# Cartridge

Manufacturer ID 0x98

Size (kB) | Device ID | Chip count
----------|-----------|-----------
32~512    |   0xAB    |    1
1024      |   0x2C    |    1
2048      |   0x2F    |    1
4096      |   0x2F    |    2

# Contact

* https://twitter.com/topapate
* https://twitter.com/jotegojp
* https://github.com/jotego/jtcores/issues

# Thanks to June 2023 Patrons
