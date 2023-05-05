# Aliens Compatible FPGA core by Jotego

# Technical Details

The PALs were dumped by Caius and are published [here](https://wiki.pldarchive.co.uk/index.php?title=Aliens). They can be found in the _doc_ folder and follow the GAL16V8 format.

## Video

- Pixel clock 12MHz
- Frame period 16.895ms => 59.18 Hz
- Tile map bandwidth = 384x4x3/64us = 72 Mbit/s
- Tile map 2.25 Mreq/s (SDRAM requests) = 144 req/line
- Hcnt from 20 to 19F. 20-60 = HB (64 pixels). 40-5A = HS
- Vcnt from F8 to 1FF. 1F0 -> F8 -> 110 = VB. F8-100 = VS

## RAM Usage

Item        | RAM size (kB)
------------|-----------
KCPU        |  8
Z80         |  2
Tile mapper | 16
OBJ         |  2
Total       | 28

The 051960 has an embedded double line buffer

# Support

The *jotego* nickname had already been used by other people so on some networks
you will find me as *topapate*.

Contact via:
* https://twitter.com/topapate
* https://github.com/jotego

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# Thanks to May 2023 Patrons