# Slap Fight / Tiger-Heli

JTFRAME implementation of Toaplan's Slap Fight PCB, developed for
[jtcores issue #130](http://gitea.jotego.es/jotego/jtcores/issues/130).

Primary hardware reference: **Slapfight Arcade PCB**, schematics created by
Neil Ward and Anton Gale, KiCad PDF dated 27 December 2022. Circuit mapping and
known source gaps are recorded in [doc/hardware.md](doc/hardware.md).

The A77 Slap Fight and Alcon boards share the same hardware. The A76 board uses
a different MCU ROM and sources screen flip from the main I/O latch. Tiger-Heli
shares the video hardware but uses fixed program ROM, inverted MCU-side status,
main-latch screen flip and a different sound-divider tap. Performan,
Guardian/Get Star and bootlegs are outside this core's current scope.

| MAME set | Game | Board |
|---|---|---|
| `slapfigh` | Slap Fight | A77 |
| `alcon` | Alcon | A77 |
| `slapfigha` | Slap Fight | A76 |
| `tigerh` | Tiger-Heli (US) | A47 |
| `tigerhj` | Tiger-Heli (Japan) | A47 |

The core executes both Z80 programs and the original 68705 firmware. Fire and
Select use buttons 1 and 2; Tiger-Heli uses Fire and Bomb. MiSTer, Pocket, SiDi
and SiDi128 builds fit and pass
static timing analysis. The core is listed as beta pending hardware testing.

RGB outputs retain the original 4 bits per channel. JTFRAME handles expansion
for display outputs. The earlier exact MAME comparisons below used the former
resistor-weighted 8-bit output; native output has different displayed RGB levels.

## Verification

From the repository root:

```bash
source setprj.sh
jtframe mra slap
lint-one.sh slap
lint-one.sh slap -d NOMAIN -d NOSOUND
simunit-all.sh --only jtslap
cores/slap/bin/sim.sh alcon -s 3000 -batch
cores/slap/bin/sim.sh slapfigh start.cab -batch
cores/slap/bin/sim.sh tigerh start.cab -batch
jtcore slap -mr --nodbg
```

Scene simulations require `JOTEGO`; the helper prepares SDRAM bank images.
Canonical Alcon scenes 1000..6000 and flipped scenes 1001, 3001 and 5001 match
MAME pixel for pixel. Slap Fight scenes 900, 1100 and 1250 also match exactly.
Separate renders of all three layers match an independent ROM decoder. MCU
handshake, video waits and colour mixing have unit simulations.

The cabinet scripts wait through the boot notice, insert a coin at frame 1100,
start player one at frame 1502 and exercise fire, select and all four directions.
The complete start script runs for 1804 frames. An earlier start pulse can occur
before the title animation accepts input.
All three Slap Fight/Alcon sets pass boot, credit, start and gameplay checks. Saved
frames confirm ship movement in all four directions and bullets after Fire;
the thirty-frame audio window after each coin is nonzero and nonconstant.

Tiger-Heli US completes the 660-frame coin/start and launch-animation script;
Japan accepts a coin in the 392-frame script. Both have nonzero coin audio.
The unit simulations check Fire/Bomb and all direction bits for both players,
the inverted MCU status inputs and the sound timer's divider and enable latch.
Nine US scenes and three flipped Japanese scenes match MAME pixel for pixel.

The PDF omits the MCU circuit and leaves a pixel-divider reset connection in
need of independent confirmation. These source gaps and the sound RAM mapping
are explained in [doc/hardware.md](doc/hardware.md).
