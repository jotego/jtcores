# JTNEMSIS — Konami GX400 (Nemesis, 1985)

FPGA compatible core for the Nemesis (1985) arcade hardware, originally written by [LMN-san][@LmnSama], [OScherler][@oscherler], and [Raki][@RCAVictorCo]. This port builds on their implementation and hardware measurements. It is in beta while the JTFRAME integration and supported-target validation are completed.

Our goal during development was to be as close to the original hardware as possible, and not to rely on superficiality and supposition, which is why, after releasing the first version, we continued improving the reproduction accuracy with more tests and measurements. Great efforts have been made towards accuracy. Raki wrote a custom ROM for the 68000 to test all possible cases of tile/sprite priority bits on original hardware. LmnSan wrote a custom ROM for the Z80 to play test sounds on all channels, at every volume and every frequency, and did a thorough analysis of the results compared to original hardware. OScherler also knows how to write custom ROMs, but the ones he made for this project are less impressive.

This core was developed using the [jtframe][] framework by Jotego ([@topapate][]). It was ported to JTCORES with help from Andrea Bogazzi. The port updates jtframe and replaces the hand-written SDRAM/download plumbing with the mem.yaml-generated interface.


[@LmnSama]:     https://twitter.com/@LmnSama
[@oscherler]:   https://tooting.ch/@oscherler
[@RCAVictorCo]: https://twitter.com/@RCAVictorCo
[jtframe]:      https://github.com/jotego/jtcores
[@topapate]:    https://twitter.com/topapate

## Installation

Install from [JTCORES for MiSTer][jtcores_mister], either via [Update All][], which installs them by default, or manually by following [these instructions][jtcores_instructions].

[jtcores_mister]: https://github.com/jotego/jtcores_mister
[Update All]: https://github.com/theypsilon/Update_All_MiSTer
[jtcores_instructions]: https://github.com/jotego/jtcores_mister#download

## Supported Games

MAME set | Game         | Status
---------|--------------|-------
nemesis  | Nemesis      | Beta
nemesisuk| Nemesis (UK) | Beta

These are the two supported ROM sets. MiSTer and Analogue Pocket are listed as beta targets in `.beta.yaml`. MiST and SiDi are skipped by `cfg/macros.def`. Neptuno is also skipped: the current design maps to 268 M9K blocks, while the target device provides 260. SiDi128 target validation is tracked in [JTCORES issue #211][issue211].

Target status:

Target | Status
-------|-------
MiSTer | Beta
Analogue Pocket | Beta
SiDi128 | Validation results tracked in issue #211
Neptuno | Skipped — 268 M9K required, 260 available
MiST | Skipped
SiDi | Skipped

Final target build and timing results are tracked in [JTCORES issue #211][issue211].

## Custom ICs

There are 8 custom Konami ICs on the Nemesis system. Most of them are used in several games.

In particular, the overall features of the GFX board were built based on a [Salamander bootleg][PCB]. We drew full schematics to figure out what the function of each IC is, and we made the clone models with the same functionalities by analyzing actual waveform captures from the original chips. In the case of the sprite engine especially, it took a lot of effort because there is a state machine that manages sprite scaling. Since it was pointed out that there was a problem with the sprite scaler of the bootleg, we made [a program][diagnostics] written in 68k assembly that can display a modifiable sprite for inspection. We measured the width and height of the sprite displayed on a Bubble System PCB and compared data with the hardware implementation of the bootleg. In addition, we found that there was a problem with the priority handler section of the MAME driver, `nemesis.cpp`. A problem with the tilemap being messed up occurred in some games originally released on Bubble System that were not currently supported by MAME. To solve the problem, we tried all priority bits, sorted cases, and implemented the original behavior exactly.

The MAME reference files in `doc/` are copied from upstream MAME commit `beb1fd5da85044961caf7541d22b6f06f6f7cc97`, authored and committed by Vas Crabb at 2026-11-09 04:30:20 +11:00 (2026-11-08 17:30:20 UTC): `src/mame/konami/nemesis.cpp`, `nemesis.h` and `nemesis_v.cpp`. `doc/mame.xml` remains the repository's MAME 0.282 reduced database, generated from `/nobackup/mame/mame0282.xml`.

[PCB]: https://twitter.com/RCAVictorCo/status/1364872798594686980
[diagnostics]: https://github.com/ika-musume/BubbleDrive8/blob/master/BubbleDrive8_diagnostics/diagnostics_main.X68

Name     | Subsystem | Function
---------|-----------|---------
K005924  | Main      | Watchdog/Coin Operation (not implemented)
K0005289 | Audio     | Pre-SCC Wavetable Sound Generator
K0005290 | GFX       | Tileline Latch
K0005291 | GFX       | Tilemap Generator
K0005292 | GFX       | Video Timing Generator
K0005293 | GFX       | Priority Handler
K0005294 | GFX       | Sprite Latch/MUX
K0005295 | GFX       | Sprite Engine

## External Modules

The core uses the following modules:

Name    | Purpose            | Author         | URL
--------|--------------------|----------------|-----
jtframe | FPGA framework     | Jotego         | https://github.com/jotego/jtcores
jt49    | AY-3-8910 PSG      | Jotego         | https://github.com/jotego/jt49
fx68k   | Motorola 68000 CPU | Jorge Cwik     | https://github.com/ijor/fx68k
T80s    | Zilog Z80 CPU      | Daniel Wallner | Included in jtframe

## Switched Resistor Ladders Modeling

The volume table that models the switched resistor ladders at the output of the K0005289 PROMs is calculated in `tools/prom_volumes.py` and saved as `hdl/prom_vol.hex`, which is loaded by the `jtframe_prom` modules. It combines a direct resistor-ladder calculation with a linear adjustment based on original-hardware audio recordings.

The color-RAM lookup table is calculated by `tools/resnet_colmix.cpp`, adapted from MAME's `resnet.cpp` with the Nemesis network values. Its measured byte values are checked in as `hdl/colmix.hex`.

The two AY-3-8910 channels use core-local `jtnemsis_jt49` copies so the Nemesis transfer curve stays scoped to this core. JTFRAME's standard `audio.yaml` mixer combines those 10-bit AY sources with the two 8-bit K005289 PROM outputs. The switched 4.7 µF capacitor C23 is modeled as an equivalent low-pass pole shared by the outputs. Its source resistance is an estimate; the variable output-volume control load is ignored because its setting is not fixed, so the exact low-frequency response can differ from a particular PCB.

## Known Issues

- Only the `nemesis` and `nemesisuk` sets are supported.
- MiST, SiDi and Neptuno are skipped by `cfg/macros.def`. MiSTer and Pocket remain beta; remaining supported-target build and timing results are tracked in [JTCORES issue #211][issue211].
- The common C23 audio pole approximates the board's shared analog output node and does not model the variable volume-control load.

Please report integration issues in the [JTCORES Gitea issue tracker][issues], and mention [@oscherler][oscherler-gh].

[issues]: http://gitea.jotego.es/jotego/jtcores/issues
[issue211]: http://gitea.jotego.es/jotego/jtcores/issues/211
[oscherler-gh]: https://github.com/oscherler

## Acknowledgements

The authors would like to thank

* Alamone, for the audio tests
* HirofumiIwasaki, for the audio recordings
* atrac17
* Ace

and

* Jotego, for the jtframe framework
* Sorgelig, for the MiSTer project
