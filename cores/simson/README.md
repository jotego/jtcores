
# PLD Equations

Derived from Caius original [files](https://wiki.pldarchive.co.uk/index.php?title=The_Simpsons).


**053994** at 11C:

```
/11D_i7 = /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 & /W0C1 & AS1 +
       /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 & W0C1 +
       /AS & /A15 & /A14 & /A13 & A12 & A11 & A10 & /AS1 +
       /AS & INIT & /A15 & /A14 & A13 & /W0C1 +
       /AS & INIT & /A15 & /A14 & /A13 & /AS1 +
       /AS & INIT & /A15 & /A14 & /A13 & A12

/11D_i6 = /AS & /INIT & /A15 & A14 & A13 & A12 & A11 & A10 +
       /AS & /A15 & /A14 & /A13 & A12 & A11 & A10

/WORKCS = /AS & INIT & /A15 & A14 & /A13

/OBJCS = /AS & INIT & /A15 & /A14 & A13 & W0C1

/COLOCS = /AS & INIT & /A15 & /A14 & /A13 & /A12 & AS1

/PROGCS = /AS & INIT & A14 & A13 & AS8 +
       /AS & A15

/BNKCS = /AS & INIT & /A15 & A14 & A13 & /AS8
```

**053995** at 11D:

```
/EEPROM = /AS & A9 & A8 & A7 & /i6 & /i7 & /A6 & /A5 & A4

/OBJREG = /AS & A9 & A8 & A7 & /i6 & /i7 & /A6 & A5 & A4

/PCUCS = /AS & A9 & A8 & A7 & /i6 & /i7 & /A6 & A5 & /AS1

/JOYSTK = /AS & A9 & A8 & A7 & /i6 & /i7 & /A6 & /A5 & /AS1

/IOCS = /AS & A9 & A8 & A7 & /i6 & /i7 & A6 & /A5 & A4

/VRAMCS = /AS & /A9 & /i6 +
          /AS & /A8 & /i6 +
          /AS & /A7 & /i6 +
          /AS & /i6 & i7 +
          /AS & i6 & /i7 +
          /AS & /i6 & A6 & A5 +
          /AS & /i6 & A6 & /AS1
```
