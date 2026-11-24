## 052606 (U61, H14)

| Pin | Net | Direction |
| --- | --- | --- |
| 1 | NAS | input |
| 2-6 | A15, A14, A13, A12, A11 | input |
| 7 | NBANK-COLOR | input |
| 8 | NROT-WORK | input |
| 9 | NROT-ROTEN | input |
| 11 | U88 LS74 Q feedback | input |
| 12 | ROM1CS | output |
| 13 | ROM2CS | output |
| 14 | COLORCS | output |
| 15 | WORKCS | output |
| 16 | ROTEN | output |
| 17 | ROTV | output |
| 18 | path toward U63 pin 1; trace pending | output |
| 19 | U88 LS74 D input | output |

## 052607 (U63, H16)

| Pin | Net | Direction |
| --- | --- | --- |
| 1 | first decoder path, likely U61 pin 18; trace pending | input |
| 2 | NAS | input |
| 3-9 | A13, A12, A11, A10, A9, A8, A7 | input |
| 11 | A6 | input |
| 19 | ROTREG | output |
| 18 | U92 LS74 D, registered OBJCS | output |
| 17 | gate path toward VRAMCS; trace pending | output |
| 16 | inverted to INTSET | output |
| 12 | gate path toward VRAMCS; trace pending | output |
