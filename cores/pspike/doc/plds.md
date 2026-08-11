# PLD dumps - Video System Co. boards

Source: [PLD Archive](https://wiki.pldarchive.co.uk). Decoded with MAME's `jedutil`:

```bash
jedutil -view <file>.jed <device>
```

`iN` / `oN` are **device pin numbers**, not signals. The pin-to-signal mapping is not
established yet, so none of this is wired into the HDL - see the note at the end.

## Power Spikes

| ID | Location | Device | Note |
|---|---|---|---|
| 1101A | U15 | 18CV8 | archive file is named `1011A`, likely a typo |
| 1102 | IC16 | 18CV8 | **identical equations to MAME's `pspikes/peel18cv8.bin`** |
| 1102 | IC16 | GAL16V8 | same device, retargeted dump |
| 1103 | U112 | 18CV8 | |

### 1101A - U15 - 18CV8
```
Outputs:

12 (Combinatorial, Output feedback output, Active low)
13 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, Output feedback output, Active low)

Equations:

/o12 = /i5 & /i6 & /i7 & /i8 & /i9 & i11 & /i14 +
       /i2 & /i3 & /i4 & /i5 & i6 & /i7 & /i8 & /i9 & i11 +
       /i1 & /i2 & /i3 & /i4 & /i5 & /i6 & i7 & /i8 & /i9 & i11
o12.oe = vcc

/o13 = i1 & i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9 & i11
o13.oe = vcc

/o16 = /i1 & /i2 & /i3 & /i4 & /i5 & /i6 & i7 & /i8 & /i9 & i11
o16.oe = vcc

/o17 = /i2 & /i3 & /i4 & /i5 & i6 & /i7 & /i8 & /i9 & i11
o17.oe = vcc

/o18 = i4 & /i5 & /i6 & /i7 & /i8 & /i9 & i11 & /i14
o18.oe = vcc

/o19 = /i4 & /i5 & /i6 & /i7 & /i8 & /i9 & i11 & /i14
o19.oe = vcc

```

### 1102 - IC16 - 18CV8
```
Outputs:

12 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
15 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, Output feedback output, Active low)

Equations:

/o12 = /i5 & i6 & i7 & i11 & /i13 +
       /i3 & /i4 & i6 & i7 & i11 & /i13 +
       /i1 & /i2 & i3 & /i4 & i5 & i6 & i7 & i8 & i9 & /i13
o12.oe = vcc

/o14 = /i3 & /i4 & i5 & i6 & i7 & i11 & /i13
o14.oe = vcc

/o15 = /i1 & /i2 & i3 & /i4 & i5 & i6 & i7 & i8 & i9 & /i13
o15.oe = vcc

/o16 = /i5 & i6 & i7 & i11 & /i13
o16.oe = vcc

/o17 = /i3 & /i4 & /i5 & /i6 & i7 & /i13
o17.oe = vcc

/o18 = /i5 & /i6 & /i7 & i11 & /i13
o18.oe = vcc

/o19 = i5 & /i6 & i7 & i11 & /i13
o19.oe = vcc

```

### 1102 - IC16 - GAL16V8 (same device, retargeted)
```
Outputs:

12 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
15 (Combinatorial, No output feedback, Active low)
16 (Combinatorial, No output feedback, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, Output feedback output, Active low)

Equations:

/o12 = /i5 & i6 & i7 & i11 & /i13 +
       /i3 & /i4 & i6 & i7 & i11 & /i13 +
       /i1 & /i2 & i3 & /i4 & i5 & i6 & i7 & i8 & i9 & /i13
o12.oe = vcc

/o14 = /i3 & /i4 & i5 & i6 & i7 & i11 & /i13
o14.oe = vcc

/o15 = /i1 & /i2 & i3 & /i4 & i5 & i6 & i7 & i8 & i9 & /i13
o15.oe = vcc

/o16 = /i5 & i6 & i7 & i11 & /i13
o16.oe = vcc

/o17 = /i3 & /i4 & /i5 & /i6 & i7 & /i13
o17.oe = vcc

/o18 = /i5 & /i6 & /i7 & i11 & /i13
o18.oe = vcc

/o19 = i5 & /i6 & i7 & i11 & /i13
o19.oe = vcc

```

### 1103 - U112 - 18CV8
```
Outputs:

12 (Combinatorial, Output feedback output, Active low)
13 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active high)
15 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active high)
19 (Combinatorial, Output feedback output, Active high)

Equations:

/o12 = 
o12.oe = vcc

/o13 = 
o13.oe = vcc

o14 = 
o14.oe = vcc

/o15 = 
o15.oe = vcc

/o16 = i1 & i2 & i3 & i4 & /i5
o16.oe = vcc

/o17 = i5 +
       /i1 +
       /i2 +
       /i3 +
       /i4
o17.oe = vcc

o18 = i5 & i7 & /i8 & /i9
o18.oe = vcc

o19 = i5 & i6 & /i8 & /i9
o19.oe = vcc

```

## Turbo Force

All GAL16V8.

| ID | Location | ID | Location |
|---|---|---|---|
| 1104B | U26 | 1107 | U29 |
| 1105A | U27 | 1108 | U150 |
| 1106 | U28 | 1109 | U100 |

### 1104B - U26 - GAL16V8
```
Outputs:

12 (Combinatorial, Output feedback output, Active high)
13 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
15 (Combinatorial, No output feedback, Active low)
16 (Combinatorial, No output feedback, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, Output feedback output, Active low)

Equations:

o12 = 
o12.oe = vcc

/o13 = /i1 & i2 & i4 & i5 & i6 & i7 & i8 & i9 +
       /i8 & i9 & i11 +
       /i3 & i4 & i5 & i6 & i7 & i8 & i9 +
       /i7 & i9 & i11 +
       /i5 & /i6 & i7 & i8 & i9
o13.oe = vcc

/o14 = /i1 & i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9
o14.oe = vcc

/o15 = i1 & /i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9
o15.oe = vcc

/o16 = /i3 & /i4 & i5 & /i6 & i7 & i8 & i9
o16.oe = vcc

/o17 = /i3 & i4 & i5 & i6 & i7 & i8 & i9 +
       /i5 & /i6 & i7 & i8 & i9
o17.oe = vcc

/o18 = /i8 & i9 & i11
o18.oe = vcc

/o19 = /i7 & i8 & i9 & i11
o19.oe = vcc

```

### 1105A - U27 - GAL16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active low)
15 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active high)
17 (Combinatorial, Output feedback output, Active high)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

/o12 = /i6 & /i7 & i8 & i9 & i11 & i14
o12.oe = vcc

/o15 = /i1 & /i2 & /i3 & /i4 & /i13 & /i14
o15.oe = vcc

o16 = 
o16.oe = vcc

o17 = 
o17.oe = vcc

/o18 = i5 & /i6 & /i7 & i8 & i9 & i11 & i14
o18.oe = vcc

/o19 = /i5 & /i6 & /i7 & i8 & i9 & i11 & i14
o19.oe = vcc

```

### 1106 - U28 - GAL16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active low)
16 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

/o12 = /i1 & /i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9 & i11 & i14
o12.oe = vcc

/o16 = i1 & /i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9 & i11 & /i13 & i15
o16.oe = vcc

/o17 = i1 & /i2 & /i3 & /i4 & i5 & i6 & i7 & i8 & i9 & i11 & i14
o17.oe = vcc

/o18 = /i1 & /i2 & /i3 & /i4 & i5 & i6 & i7 & i8 & i9 & i11 & i14
o18.oe = vcc

/o19 = i1 & /i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9 & i11 & /i13 & i15 +
       /i1 & /i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9 & i11 & i14
o19.oe = vcc

```

### 1107 - U29 - GAL16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active low)
13 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

/o12 = /i4 & /i5 & /i6 & /i7 & /i8 & i9 & /i11
o12.oe = vcc

/o13 = i1 & i2 & /i3 & /i4 & /i5 & /i6 & /i7 & i8 & i9 & /i11
o13.oe = vcc

/o14 = i1 & i2 & i3 & /i4 & /i5 & /i6 & /i7 & /i8 & i9 & /i11
o14.oe = vcc

/o16 = /i1 & /i2 & i3 & /i4 & /i5 & /i6 & /i7 & i8 & i9 & /i11
o16.oe = vcc

/o17 = i1 & /i2 & /i3 & /i4 & /i5 & /i6 & /i7 & i8 & i9 & /i11
o17.oe = vcc

/o18 = /i1 & /i2 & /i3 & /i4 & /i5 & /i6 & /i7 & i8 & i9 & /i11
o18.oe = vcc

/o19 = /i1 & i2 & /i3 & /i4 & /i5 & /i6 & /i7 & i8 & i9 & /i11
o19.oe = vcc

```

### 1108 - U150 - GAL16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active high)
13 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active high)
18 (Combinatorial, Output feedback output, Active high)
19 (Combinatorial, No output feedback, Active low)

Equations:

o12 = 
o12.oe = vcc

/o13 = /i1 & /i2 & /i4 & /i5 +
       /i2 & i3 & /i5
o13.oe = vcc

/o14 = /i2 & i5 +
       /i1 & /i2 & /i3
o14.oe = vcc

o17 = /i2 & i3 & /i4 & /i5 +
      /i1 & /i2 & i4 & /i5 +
      /i2 & i3 & i4 & /i5
o17.oe = vcc

o18 = /i2 & i3 +
      i1 & /i2 +
      /i2 & i5
o18.oe = vcc

/o19 = /i2 & /i3 & /i5
o19.oe = vcc

```

### 1109 - U100 - GAL16V8
```
Outputs:

12 (Combinatorial, Output feedback output, Active high)
13 (Combinatorial, Output feedback output, Active high)
14 (Combinatorial, Output feedback output, Active high)
15 (Combinatorial, No output feedback, Active high)
16 (Combinatorial, No output feedback, Active low)
17 (Combinatorial, Output feedback output, Active high)
18 (Combinatorial, Output feedback output, Active high)
19 (Combinatorial, Output feedback output, Active high)

Equations:

o12 = 
o12.oe = vcc

o13 = 
o13.oe = vcc

o14 = 
o14.oe = vcc

o15 = 
o15.oe = vcc

/o16 = i1 & i2 & i3 & i4 & /i5
o16.oe = vcc

o17 = i1 & i2 & i3 & i4 & /i5
o17.oe = vcc

o18 = i5 & i7 & /i8 & /i9
o18.oe = vcc

o19 = i5 & i6 & /i8 & /i9
o19.oe = vcc

```

## Aero Fighters

Two board revisions. `U163` and `U139` are populated on both.

| Revision | ID | Location | Device |
|---|---|---|---|
| rev 1 | 1104C | U163 | PALCE16V8 |
| rev 1 | 1109A | U139 | PALCE16V8 |
| rev 2 | TI921 | U163 | GAL16V8 |
| rev 2 | TI922 | U160 | GAL16V8 |
| rev 2 | TI923 | U139 | GAL16V8 |

### Revision 1

#### 1104C - U163 - PALCE16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active low)
13 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

/o12 = /o14 +
       /o18 +
       /o13
o12.oe = vcc

/o13 = /i8 & i11
o13.oe = vcc

/o14 = /i3 & i4 & i5 & i6 & i7 & i8 & i15 +
       /i5 & /i6 & i7 & i8 & i15
o14.oe = vcc

/o17 = i1 & i2 & i3 & i4 & i5 & i6 & i7 & i8 & i9
o17.oe = vcc

/o18 = i1 & /i2 & i3 & i4 & i5 & i6 & i7 & i8 & i15
o18.oe = vcc

/o19 = /i3 & /i4 & i5 & /i6 & i7 & i8 & i9
o19.oe = vcc

```

#### 1109A - U139 - PALCE16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active low)
13 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
15 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

/o12 = i6 & /i7 & /i9 & /i11
o12.oe = vcc

/o13 = i6 & i7 & /i9 & /i18
o13.oe = vcc

/o14 = /i5 & /i8 +
       /i2 & /i8 +
       /i3 & /i8 +
       i1 & /i8 +
       /i4 & /i8
o14.oe = vcc

/o15 = /i1 & i2 & i3 & i4 & i5 & /i8
o15.oe = vcc

/o16 = /i6 & /i7 & /i9
o16.oe = vcc

/o19 = /i6 & i7 & /i9 & /i11
o19.oe = vcc

```

### Revision 2

#### TI921 - U163 - GAL16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active high)
13 (Combinatorial, Output feedback output, Active low)
15 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

o12 = i1 & i2 & i3 & i4 & i5 & i6
o12.oe = vcc

/o13 = i3 & i4 & i5 & /i6 & i7 +
       /i3 & /i4 & i5 & i7 +
       /i1 & i7 +
       /i2 & i7 +
       /i4 & /i5 & i7
o13.oe = vcc

/o15 = i1 & i2 & i3 & /i4 & /i5 & i6 & i7
o15.oe = vcc

/o16 = i1 & i2 & i3 & /i4 & /i5 & /i6 & i7
o16.oe = vcc

/o17 = i1 & i2 & i3 & i4 & i5 & /i6 & i7 +
       i1 & i2 & /i3 & /i4 & i7
o17.oe = vcc

/o18 = /i2 & i7 +
       /i1 & i7
o18.oe = vcc

/o19 = i1 & i2 & /i3 & i4 & /i5 & /i6 & i7
o19.oe = vcc

```

#### TI922 - U160 - GAL16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active low)
13 (Combinatorial, Output feedback output, Active low)
15 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
17 (Combinatorial, Output feedback output, Active low)
18 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

/o12 = i1 & /i2 & /i3 & /i4 & i11
o12.oe = vcc

/o13 = i1 & /i2 & /i3 & i7 & i11 +
       /i1 & i2 & i7 & i11
o13.oe = vcc

/o15 = i1 & i2 & i7 & i11
o15.oe = vcc

/o16 = i1 & /i2 & /i3 & i4 & i7 & i11
o16.oe = vcc

/o17 = /i1 & i2 & i7 & i11
o17.oe = vcc

/o18 = /i1 & /i2 & /i3 & i4 & i7 & i11
o18.oe = vcc

/o19 = /i1 & /i2 & /i3 & /i4 & i7 & i11
o19.oe = vcc

```

#### TI923 - U139 - GAL16V8
```
Outputs:

12 (Combinatorial, No output feedback, Active low)
13 (Combinatorial, Output feedback output, Active low)
14 (Combinatorial, Output feedback output, Active low)
15 (Combinatorial, Output feedback output, Active low)
16 (Combinatorial, Output feedback output, Active low)
19 (Combinatorial, No output feedback, Active low)

Equations:

/o12 = i6 & /i7 & /i9 & /i11
o12.oe = vcc

/o13 = i6 & i7 & /i9 & /i18
o13.oe = vcc

/o14 = /i5 & /i8 +
       /i4 & /i8 +
       /i3 & /i8 +
       /i2 & /i8 +
       i1 & /i8
o14.oe = vcc

/o15 = /i1 & i2 & i3 & i4 & i5 & /i8
o15.oe = vcc

/o16 = /i6 & /i7 & /i9
o16.oe = vcc

/o19 = /i6 & i7 & /i9 & /i11
o19.oe = vcc

```

## Before using any of this in HDL

The equations are anonymous: `i5`, `i11`, `o16` are pin numbers. Turning them into address
decoding needs the pin-to-signal mapping, from a pinout or by tracing the PCB.

For Power Spikes the `1102` device is the promising one - five outputs, a common `/i13` enable,
and the board has exactly five decoded regions (`ff8000` VRAM, `ffc000` OBJ, `ffd000` raster,
`ffe000` palette, `fff000` I/O). Fitting the terms against that map would identify the pins, but
that is inference from the memory map, not a verified pinout, and must be labelled as such.
