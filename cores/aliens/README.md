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

## PAL Equations

From D21

```
/y = /o12 = /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & W0C0

/WORK = /AS & /A15 & /A14 & /A13 & /A12 & /A11 & A10 +
       /AS & /A15 & /A14 & /A13 & /A12 & A11 +
       /AS & /A15 & /A14 & /A13 & A12 +
       /AS & /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & /W0C0

/BANK = /AS & /BK4 & /A15 & /A14 & A13

/x = /o15 = /AS & /A15 & A14 & /A13 & A12 & A11 & A10

/z = /o16 = INIT & /A15 & A14 & A13 & A12 & A11

/p = /o17 = /AS & /A15 & A14 +
       /AS & /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & W0C0

/PROG = /AS & A15 +
       /AS & BK4 & /A15 & /A14 & A13

/o19 = /AS & A15 +
       /AS & BK4 & /A15 & /A14 & A13 +
       /AS & /A15 & /A14 & /A13 & /A12 & /A11 & A10 +
       /AS & /A15 & /A14 & /A13 & /A12 & A11 +
       /AS & /A15 & /A14 & /A13 & A12 +
       /AS & /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & /W0C0 +
       /AS & /BK4 & /A15 & /A14 & A13
```

From D20

```
/DTAC' = /p' & /RMRD & /A10 & /A9 & /A8 & /A7 & /i9 & /i11 & /z +
       /p' & /RMRD & A10 & /z +
       /p' & /p & IOCS & aux

/IOCS = A9 & A8 & A7 & /i9 & /x

/aux = /p' & /RMRD & /A10 & /A9 & /A8 & /A7 & /i9 & /i11 & /z +
       /p' & /RMRD & A10 & /z

/CRAMCS = /p' & /i8

/VRAMCS = /p' & /p & i8 & IOCS & aux

/OBJCS = /p' & /RMRD & /A10 & /A9 & /A8 & /A7 & /i9 & /i11 & /z +
       /p' & /RMRD & A10 & /z

```



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