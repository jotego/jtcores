<!-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
     SPDX-License-Identifier: GPL-3.0-or-later
     Date: 18-10-2026 -->

# Hardware verification

Findings from joint review of the Seicross SZ-1/SZ-2, Frisky Tom FT-1B/FT-2B
and Radical Radial schematics (PDF pages 6–7). Originals remain outside the
repository. Pin numbers below are physical package pins; `/` means inversion
or an active-low signal. `P` is treated as logical high.

The user confirmed identical PAL 2C wiring on all three boards. This does not
establish identical PAL programs or every upstream circuit. Unconfirmed readings
and modeling choices are identified below; remaining checks are in
[pending_verifications.md](pending_verifications.md).

The [KiCad project](../sch/seicro.kicad_pro) contains functional audio, power,
colour, RAM-control and address-counter sheets, plus CPU/video placement sheets.
It is a partial reconstruction; unwired pins are not verified connections.

## Clocks, reset and interrupts

| Circuit | Verified wiring and resulting logic |
| --- | --- |
| Master divider | 3C type 107: upper J1 ← lower /Q6, lower J8 ← upper Q3; both K and /CLR tied P. Both clocks come from oscillator 5 through 3B. The state cycle divides by three. Nominal 18.432 MHz gives 6.144 MHz, high for one oscillator period and low for two. |
| MCLK polarity | 3C Q3 → inverting 3B output 13 → /MCLK; 3C /Q2 → 3B input 2/output 3 → MCLK. The first buffer input number is inferred, not legible. Horizontal counters use raw 3C /Q2. |
| Horizontal count | 5A D2 ← /Q6; Q5 enables both 4B enable pins 7/10. 4B carry 15 enables both 4C pins 7/10. 4B data is zero; /LOAD9 is P. 4C data is 0100; carry 15 → 4A13/inverted12 → its own /LOAD9. Derived count: 128…511, then 128. |
| Vertical clock/blank | /H8 → 5A CK11; V0 Q9 enables 5B pins 7/10. 6A NAND inputs 1/2/13 = V5/V6/V7 → 5F D12; CK11 = V4, /PRE10 and /CLR13 = P. 5F /Q8 = VBLK; Q9 = /VBLK. Derived blank: V240 through V15. |
| CLK60 | Non-inverting AND 5M: input 9 = VBLK, input 10 = P. Its rising edge clocks the watchdog and Z80 interrupt latch. |
| Watchdog clear | Active-low /RD7 and the 1k pull-up/contact node feed the bubbled OR symbol ending in 08: physical AND output 3 → 4N /CLR1. The contact's exact mechanical form is unconfirmed. |
| Watchdog reset | 4N type 161: enables 7/10 and /LOAD9 = P, CK2 = CLK60. Carry 15 → 4K1/2 → 4H1; power-on node R13/C2/D3 → 4H2; output 3 → 4K3/4 → /RESET. Result: /RESET = !carry & power_ready; count 15 asserts reset for one frame, then wraps. |
| Z80 /INT | 5N D2 = GND, /CLR1 = P, /PRE4 = AY B0/pin 13 (/ACK), CK3 = CLK60; Q5 → Z80 /INT16. /ACK low deasserts IRQ; the next frame edge asserts it. CPU interrupt acknowledge does not clear this latch. |
| MCU reset | AY B2/pin 11 → 5N CK11; D12 and /PRE10 = P; Q9 → MCU /RESET40. /CLR13 comes from 4I3 = global /RESET & 5O QB2. A B2 rising edge releases the MCU; subsequent edges do not pulse reset. |
| AC monitor counter | 5O type 193: data 9/10/1/15 and CU5 = P, CD4 = CLK60, CLR14 = GND, /LOAD11 ← NE555 output 3. The 555 input feed comes from AC6V through D5, crossing +12V/GND without joining them. Analogue thresholds remain unverified. |

These are ideal logic derivations. At 6.144 MHz and 384 × 264 pixels, one
frame is 16.5 ms; the watchdog wraps every 264 ms. Buffered clock skew and
power-up phases have not been measured.

## PAL programs and /WAIT

Dump identities match the local [MAME driver](seicross.cpp). All three dumps
are 68-byte binary maps containing 512 fuses, decoded with MAME `jedutil`.

| Sets | Dump | CRC32 | SHA1 | Raw equations |
| --- | --- | --- | --- | --- |
| radrad, radradj | pal16h2.2b | a356803a | a324d3cbe2de5bf54be9aa07c984054149ac3eb0 | [Radical Radial](radrad-pal16h2-equations.txt) |
| seicross, seicrossa, sectrzon, sectrzona | pal16h2.3b | e1a6a86d | 740a5c2ef8a992f6a794c0fc4c81eb50cfcedc32 | [Seicross](seicross-pal16h2-equations.txt) |
| sectrzont | czt_pal16h2cn.bin | 7edec1ed | 1b28cb250875f14a76d84bfc0b23ee02b1862c2c | [Tecfri](sectrzont-pal16h2-equations.txt) |

radradj, seicrossa and sectrzon borrow dumps marked BAD_DUMP in the driver.
Frisky Tom has no declared PAL dump; it uses the user-approved Radical Radial
fallback. The Tecfri program uses the common pin map without an independently
traced Tecfri schematic.

Reproduce a decode with an extracted dump, kept in ignored scratch storage:

```sh
/Users/andreabogazzi/develop/mame/jedutil -view extracted-dump.bin PAL16H2
```

### Physical 2C pin map

| Pin(s) | Net or destination | Qualification |
| --- | --- | --- |
| 1, 2, 3 | /MQ1, /MQ2, /MQ3 | Jointly confirmed labels; upstream decode remains qualified. |
| 4 | H2, unbarred | User-confirmed polarity. |
| 5, 6, 7, 8, 9 | H3, H4, H5, H6, H7 | Scan traces. |
| 11 | Appears /H0 | Label/bar unresolved; eliminated from simplified equations. |
| 12, 13, 14, 17, 18 | V0, V1, V2, V3, V4 | Scan traces; eliminated from simplified equations. |
| 15 | Lower 2D CK3; 1000 pF branch to GND | Scan trace; loaded-clock delay unmeasured. |
| 16 | Upper 2D CK11 | Scan trace. |
| 19 | /VBLK, from 5F Q9 | Jointly confirmed. |
| 10, 20 | Device GND, VCC | Device roles; board supply routes untraced. |

Both outputs are active-high, always enabled, combinational and have no
feedback. With `iN`/`oN` denoting physical pins, `!` NOT, `&` AND and `|` OR,
the equations used by [jtseicro_pal](../hdl/jtseicro_pal.v) are:

```text
All programs: o15 = i4; o15.oe = 1; o16.oe = 1
Radical:      o16 = (i6 & i7 & i8 & i9) | (!i2 & i19) | !i3
Seicross:    o16 = (i6 & i7 & i8 & i9) | i19 | !i3
Tecfri:      o16 = i19
```

These match all original product terms over 65,536 input combinations per
program. For `T = H4&H5&H6&H7`, `MQ2 = !/MQ2`, `MQ3 = !/MQ3`:
PAL15 = H2; PAL16 is `T | MQ3 | (MQ2 & /VBLK)` for Radical,
`T | MQ3 | /VBLK` for Seicross and `/VBLK` for Tecfri.

### Request decode and latch

- 2F type 138: apparent A/B/C pins 1/2/3 = AB11/12/13;
  /G2A4 ← 4K8, inverted AB15 from pin 9; /G2B5 appears /ZMR;
  G1 pin 6 appears /ZRB. Y1/2/3 pins 14/13/12 supply /MQ1/2/3.
  Address digits and the final character of /ZM(*) remain unresolved.
- The adopted qualifier is `!mreq_n & rfsh_n`, with A14 ignored: MQ1/2/3
  select 0x8800/0x9000/0x9800 windows of 0x800 bytes, mirrored at
  0xC800/0xD000/0xD800. These windows remain conditional on the decode readings;
  /ZRB = buffered /RFSH is a working assumption.
- 2D upper D12 and /PRE10 = P; lower D2 and /PRE4 = P
  (presets jointly confirmed on Radical; Frisky presets scan-derived).
  Upper Q9 → lower /CLR1; lower /Q6 → upper /CLR13.
  Upper /Q8 is /WAIT. Its CPU route through 1M13/12=GND/output11 →
  Z80 /WAIT24 is scan-derived.
- Rising PAL16 sets upper Q and asserts /WAIT. The next rising PAL15/H2
  sets lower Q, clears upper Q and returns the pair to idle. A held PAL16
  does not retrigger. Same-tick release priority in RTL is a modeling choice;
  the 1000 pF capacitor does not establish a known delay.

## MCU /MR arbitration

The request/release paths below were jointly traced on Radical Radial page 6.

| Path | Physical connections |
| --- | --- |
| E | MCU 4F37 → 5H4/5 → ME |
| VMA | MCU 4F5 → 5H14/13 → MVMA; 5H is type 367 |
| Request qualifier | ME/MVMA → 4I12/13 → 11; output 11 branches to upper 4I4 and lower 4I10 |
| Address/request | MCU A15/25 → 4J11/10 → 4J13/12 → lower 4I9; lower output 8 → upper 5I CK11 |
| Feedback | Upper 5I Q9 → both lower 5J/5I /PRE4; lower 5I Q5 → upper 5I /CLR13 |
| Release data | GND → lower 5J D2; 5J Q5 → lower 5I D2; both lower /CLR1 = P |
| Release clocks | /ZMR → 4K5/6 → 5L4; other input 5 appears /ZRB. 5L is type 00, inverted output 6 → lower 5J CK3 and 4J5/6 → lower 5I CK3 |

Upper 5I /Q8 → MCU /MR3, and its D12 and /PRE10 → P, are scan-derived.
Request clock = `ME & MVMA & A15`. Let `C = 5L6 = /ZMR | !X`, where
`X` is the uncertain /ZRB input. RTL uses `C = mreq_n | !rfsh_n`.

A request asserts /MR. The next C rising edge loads zero into lower 5J;
the following falling edge loads it into lower 5I and clears the request.
A falling edge alone cannot release it. This is Z80-bus-dependent arbitration,
not a fixed MCU-cycle delay. Coincident request/release ordering is modeled,
not measured. CPU/watchdog reset does not reset the independent WAIT/MR latches.

The MCU uses the shared [jt680x](../../../modules/jt680x/doc/complete_6802.md)
engine. Applying M6802 bus timing to NSC8105 and using its board interface for
M6802 variants are compatibility choices. Undocumented Frisky Tom FC handling
is also a compatibility layer, unsupported by the Motorola manual or schematics.

## Video blanking and colour

| Chain | Verified wiring/function |
| --- | --- |
| Retimed clears | 5E D2/D12 = VBLK; CK3 = V0&H4 from 6C12/13/11; CK11 = /EFT3 from 5D9. /Q6 → 9D /CLR1; /Q8 → 8O /CLR1. 5E /CLR and /PRE pins 1/4/10/13 = P. |
| H/V sampling | 3D D2 = /H8, CK3 = H2, Q5 = /H8:2; /CLR1 and /PRE4 = P. A 330 pF clock-node capacitor was reported. 6J D6 = VBLK, CK9 = H2, /CLR1 = P, Q7 → 6D13; /H8:2 → 6D12. |
| Data blank | 6D type 32, bubbled inputs/output: physical output 11 = /H8:2 OR 6J.Q7 → 8N D6. 8N CK9 = /CDT3, /CLR1 = P; Q7 → 7E13/inverted12 → 9D D3/Q2. |
| Bank phase | /H8:2 → 6B D12, CK11 = H3; Q9 → its other half CK3. D2 ← /Q6; all asynchronous controls = P. Q9 (`T`) is high at H136…263; /Q6 (`S`) toggles at H136 once per line. Initial bank is unspecified. |
| /CDT3 | 4E12 = /H8, 13 = H3 (both circled), output 11 → 4E10; H0 → 4E9; inverted output 8 → 5D /G1. H1/H2 → 5D2/3; output 7 = /CDT3 = `!(H0&H1&H2&(H8\|!H3))`. |

### Pixel selection and palette latch

Let `a1:a0` be readout bits 1:0, `n9 = 9O9`, `n12 = 9O12`.
7A type 02: inputs 11/12 = a1/a0, output 13 → 8D select 1;
inputs 2/3 = n9/a0, output 1 → 7C1;
inputs 5/6 = n12/a1, output 4 → 7C5. The latter two gates have bubbled
inputs and unbubbled outputs. 7C type 32 has no bubbles, inputs 2 = a1,
4 = a0. Thus `7C3 = a1 | !(n9|a0)`, `7C6 = a0 | !(n12|a1)`.

8D type 157, /G15 = GND: A pins 14/11/5/2 ← readout bits 5/4/3/2;
B pins 13/10/6/3 ← 8N outputs 2/5/12/15; outputs 12/9/7/4.
Select = `!(a1|a0)`: nonzero readout pixel wins; zero selects inverted 9O
pixel data and the 8N palette. Upstream layer identities are not yet established.

| Source | 9D input → output | Destination |
| --- | --- | --- |
| 8D12 | 17 → 16 | PROM bank qualification through 7D/7E |
| 8D9 / 7 / 4 | 14 → 15 / 7 → 6 / 4 → 5 | Both PROMs pins 14/13/12 (A4/A3/A2) |
| 7C3 / 6 | 13 → 12 / 8 → 9 | Both PROMs pins 11/10 (A1/A0), no inversion |
| 7D8, OR of 7C3/6 at inputs 9/10 | 18 → 19 | Selected-pixel-nonzero qualification |

9D is type 273, CK11 = /MCLK. Define `B = 9D.Q16`, `Q = 9D.Q2 & 9D.Q19`.
Q2/Q19 pass through 7E3/4 and 5/6 into bubbled 7D4/5/output6.
That output feeds 7D13 and 2; B feeds 7D12 and 7E1/2 → 7D1.
Bubbled 7D outputs 11/3 drive PROM 9C/9B /CE15:
`9C enabled = Q & !B`, `9B enabled = Q & B`.
Blanking or a zero pixel disables both PROMs.

RGB bit order is user-confirmed: D0…D2 red, D3…D5 green, D6…D7 blue;
connector pins 1/2/3 = R/G/B. Red/green ladders use 220/470/1000 ohm,
blue 220/470 ohm, with one 470-ohm pull-down per colour. Parallel PROM
output wiring remains inferred; individual output/resistor routes are pending.

## Video RAM banks and address generation

The six-bit banks are upper 10D…10I and lower 10J…10O, ordered bits 5…0.
RAM DOUT7 feeds read muxes 8A/8B; A inputs select lower, B select upper.
8A output pins 12/9/7/4 supply bits 5…2; 8B12/9 supply bits 1/0.
Both /G15 = GND and S1 = `S = 6B./Q6`: S=0 reads lower, S=1 reads upper.

Both banks share these write words, tapped before 9D:

| Bits | Word A | Word B | Upper/lower write muxes |
| --- | --- | --- | --- |
| 5…2 | 8D12/9/7/4 | 8E12/9/7/4 | 9E / 9F |
| 1…0 | 7C3/6 | Lower 7C11/8 | 9G / 9H |

For each type 157, A pins are 14/11/5/2, B pins 13/10/6/3, outputs
12/9/7/4 (first two channels for G/H) → corresponding RAM DIN11.
9E/9G S1 = !S, /G15 = `!(T|!S)`; 9F/9H S1 = S, /G15 = `!(T|S)`.
The readout bank receives A when T=1 and zero when T=0; the other receives B.
Both banks have /CS10 = GND and /WE8 = /MCLK: nominal writes are MCLK high,
reads MCLK low, using the qualified 2147-family function.

| Address path | Verified mapping, descending bit order |
| --- | --- |
| RAM pins | Bits 7…0 → 16/17/1/2/3/4/5/6; pins 12…15 grounded. Six one-bit chips give 256 × 6 bits per bank. |
| Address mux outputs | Upper 8I/8J and lower 9I/9J, each output 12/9/7/4; /G15 = GND, S1 = 6B.Q5 = !S. |
| Source C | Two type 161 counters (upper 8H, lower designator unconfirmed), outputs 11/12/13/14 per nibble → upper mux B, lower mux A. |
| Source X | 9L/9K outputs 6/3/11/8 per nibble → upper mux A, lower mux B. Readout bank always gets X; the other gets C. |
| X generation | Type 163 counters 8M/8L outputs 11/12/13/14 → type 86 XOR inputs 4/1/12/9 of 9L/9K. Other inputs 5/2/13/10 all ← 8F5: `X = counter XOR {8{8F5}}`. |
| Inversion latch | AY B1/pin 12 H.V.INV → 5H2/3 → INV; 5H type 367 /G1 and /G15 = GND. AND 6C1=H8, 2=INV, output 3 → 8F D4; CK9=H3, /CLR1=P. F=8F5 samples H8&INV on H3 rising. |
| Counter controls | 8M/8L CK2=/MCLK; data pins 6/5/4/3 ← CD7…4 / CD3…0. /CLR1=P; lower enables 7/10=P; lower carry 15 → upper enables 7/10. /LOAD9=/CDTALD. |
| /CDTALD | 4D type 157: A14=P, B13=/CDT3, S1=/H8, /G15=GND, output 12=/CDTALD. Low at H135/151/167/183/199/215/231/247; otherwise the counters increment. |

The generic object buffer has not been equated with these physical banks,
addresses or write/clear phases. `jtseicro_blanking` models the traced controls
separately; physical latch ordering is not fully integrated into the renderer.

### CD bus and write control

CD is separate from the local bus joining 4M/4N/4O/5N; crossings are not junctions.

| Chain | Physical mapping |
| --- | --- |
| RAM → CD | 3I outputs 11/12/13/14 = bits 7…4; 2I11/12/13/14 = bits 3…0. Type 367 buffer pairs: 3J10→9, 6→7, 12→11, 4→5, 14→13, 2→3; 3K14→13, 12→11. 3J /G1,/G15 and 3K /G15 = GND, continuously enabled. |
| Write ownership | 3F12 → both 3I/2I /WR10 and input buffers 2J /G1,/G15, 2K /G15. Both RAM /CS8=GND. Low writes RAM and enables CPU buffers. |
| 3F selector | Type 157: A14=/WR3, B13=P, S1=RAM3S, /G15=GND; output 12=`RAM3S \| /WR3`. 3H/2H share S1=RAM3S and grounded /G15. |
| RAM3S | 4E AND inputs H3/H2 at 1/2, inverted output 3 → 4D B3; /H2 → A2, S1=/H8. 4D output 4 → bubbled OR 3E12; /VBLK from 5F9 → bubbled 3E13; bubbled output 11=RAM3S. Result: `/VBLK & (!H2 \| (!H8 & !H3))`. |
| /WR3 source | CPU 2E type 138 Y3, circled output 12 = /WR3. Selector labels apparently AB13/12/11; enables apparently AB15, /ZM(*), /ZWR. These input readings do not yet establish an address window. |
| Separate local bus | 4M11/12/13/14 → local bits 7…4; 4N11/12/13/14 → 3…0. Type 245 4O B-side DB7…0 pins 11/13/15/17/12/14/16/18 connect through A-side 9/7/5/3/8/6/4/2. 5N also joins this bus; its capture pins remain open. |

## Audio

| Circuit | Verified connections/values |
| --- | --- |
| AY source | AY A/B/C audio outputs joined → lower 4066 1C common analogue input. Control IO0…7 is AY port A. |
| PSG gain | IOA0/1/2/3 control R31/R33/R32/R34 = 800k/400k/200k/100k toward LM3900 1A; feedback R37=47k. Separate +5V → 100k bias feed joins the LM3900 side; its original reference is unknown. |
| DAC reference | IOA4/5/6/7 → R26/R27/R28/R29 = 800k/400k/200k/100k, with four 3.3k pull-ups to +5V; R36=47k feedback. Middle 1A output 9 feeds all upper 4066 2B analogue inputs. |
| Sample switches | MCU D4…7 → latch 2C V0…3; V0/V1/V2/V3 control R16/R17/R19/R18 = 400k/200k/400k/200k; R38=47k feedback. Relative conductances are 1:2:1:2, not binary weights. |
| Final mixer | R40/R41 are both 100k; individual PSG/DAC assignment remains unresolved. R39=47k feedback. Capacitors are across R37 and R39 only; none across R38. |
| Volume/output | LM3900 output 4 → R42 22k volume potentiometer → coupling capacitor → amplifier input 6. Amplifier supply 2=12V, ground 4; C9=47u at pin 7, C7=47u between pin 3 and output 1; speaker coupling C10=470u confirmed on board. |

The clearer schematic uses 800k/400k nominals; board photos show 820k/390k.
R30 and R35 appear unpopulated, without removing the separately traced bias feed.
The feedback caps read 0.001; interpreting the unit as µF gives 1 nF. This is
an inference, implemented in mem.yaml as two 47k/1n poles on PSG and one on DAC.
AY amplitude/calibrated analogue gain remain unmeasured.

The output IC is marked MB1712 on the drawing; MB3712 is the user-selected
working identification. Its input capacitor value is uncertain; 8-ohm speaker
impedance is an assumption. No speaker high-pass filter was added.
