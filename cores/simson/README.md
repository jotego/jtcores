
# PLD Equations

Derived from Caius original [files](https://wiki.pldarchive.co.uk/index.php?title=The_Simpsons).


**053994** at 11C:

```
/11D_i7 = /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 & /W0C1 & W0C0 +
          /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 &  W0C1 +
          /AS &         /A15 & /A14 & /A13 & A12 & A11 & A10 &        /W0C0 +
          /AS &  INIT & /A15 & /A14 &  A13 &                   /W0C1 +
          /AS &  INIT & /A15 & /A14 & /A13 &                          /W0C0 +
          /AS &  INIT & /A15 & /A14 & /A13 & A12

# 1C00~1FFFF and if /INIT 7C00~7FFF
/11D_i6 = /AS & /INIT & /A15 &  A14 &  A13 & A12 & A11 & A10 +
          /AS &         /A15 & /A14 & /A13 & A12 & A11 & A10   =
          /AS & ( A[15:10]==1C || (A[15:10]==7C && /INIT))

/WORKCS = /AS & INIT & /A15 & A14 & /A13

/OBJCS = /AS & INIT & /A15 & /A14 & A13 & W0C1

/COLOCS = /AS & INIT & /A15 & /A14 & /A13 & /A12 & W0C0

/PROGCS = /AS & INIT & A14 & A13 & BK4 +
       /AS & A15

/BNKCS = /AS & INIT & /A15 & A14 & A13 & /BK4
```

**053995** at 11D:

```
/EEPROM = /AS & /i6 & /i7 & A9 & A8 & A7 & /A6 & /A5 & /A4
/OBJREG = /AS & /i6 & /i7 & A9 & A8 & A7 & /A6 &  A5 & /A4 # A[9:4]==111010
/PCUCS  = /AS & /i6 & /i7 & A9 & A8 & A7 & /A6 &  A5 &  A4
/JOYSTK = /AS & /i6 & /i7 & A9 & A8 & A7 & /A6 & /A5 &  A4
/IOCS   = /AS & /i6 & /i7 & A9 & A8 & A7 &  A6 & /A5 & /A4

/VRAMCS = /AS & /i6 &      /A9  +
          /AS & /i6 &      /A8  +
          /AS & /i6 &      /A7  +
          /AS & /i6 &  i7 +
          /AS &  i6 & /i7 +
          /AS & /i6 &       A6 & A5 +
          /AS & /i6 &       A6 & A4
```
