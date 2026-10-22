# FPGA Clone of Konami GX400 Arcade System for MiSTer

FPGA compatible core for the Nemesis (1985) arcade hardware for MiSTer FPGA, written by [LMN-san][@LmnSama], [OScherler][@oscherler], and [Raki][@RCAVictorCo]. This core is based on the Nemesis schematics from Konami and has been verified against several different physical PCBs (Konami Bubble System, Salamander, Salamander Bootleg). The game is fully playable and there are no known issues.

Our goal during development is to be as close to the original hardware as possible, and not to rely on superficiality and supposition, which is why, after fixing the visible problems, we are going to continue improving the reproduction accuracy with more tests and measurements. Great efforts have been made towards accuracy. Raki wrote a custom ROM for the 68000 to test all possible cases of tile/sprite priority bits on original hardware. LmnSan wrote a custom ROM for the Z80 to play test sounds on all channels, at every volume and every frequency, and did a thorough analysis of the results compared to original hardware. Olivier also knows how to write custom ROMs, but the ones he made for this project are less impressive.

This core is developed using the [jtframe][] framework by Jotego ([@topapate][]). It is in active development and the source code will be published once it is out of Beta. It needs an SDRAM module to run.

[@LmnSama]:     https://twitter.com/@LmnSama
[@oscherler]:   https://twitter.com/@oscherler
[@RCAVictorCo]: https://twitter.com/@RCAVictorCo
[jtframe]:      https://github.com/jotego/jtframe
[@topapate]:    https://twitter.com/topapate

## Supported Games

Game         | Status      | Release
-------------|-------------|----------
Nemesis      | Implemented | Beta
Nemesis (UK) | Implemented | Beta
RF2          | In Progress | None
Konami GT    | In Progress | None

## Custom ICs

There are 8 custom Konami ICs on the Nemesis system. Most of them are used in several games. 

Especially, overall features of the GFX board were built based on a [Salamander bootleg][PCB]. We drew full schematics to figure out what the function of each IC is, and we made the clone models with the same functionalities by analyzing actual waveform captures from the original chips. In particular, in the case of the sprite engine, it took a lot of effort because there was a state machine that manages sprite scaling. Since it was pointed out that there was a problem with the sprite scaler of the bootleg, we made [a program][diagnostics] written in 68k assembly that can display a modifiable sprite for inspection. We measured the width and height of the sprite displayed on a Bubble System PCB and compared data with the hardware implementation of the bootleg. In addition, we found that there was a problem with the priority handler section of the MAME driver, `nemesis.cpp`. A problem with the tilemap being messed up occurred in some games originally released on Bubble System that were not currently supported by MAME. To solve the problem, we tried all priority bits, sorted cases, and implemented the original behavior exactly.

These ASIC models were originally prepared for the implementation of Bubble System, but were slightly modified for Nemesis. We expect it to be available for all GX400 games in the near future.

[PCB]: https://twitter.com/RCAVictorCo/status/1364872798594686980
[diagnostics]: https://github.com/ika-musume/BubbleDrive8/blob/master/BubbleDrive8_testprogram/testprogram_main.X68

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
jtframe | FPGA framework     | Jotego         | https://github.com/jotego/jtframe
jt49    | AY-3-8910 PSG      | Jotego         | https://github.com/jotego/jt49
fx68k   | Motorola 68000 CPU | Jorge Cwik     | https://github.com/ijor/fx68k
T80s    | Zilog Z80 CPU      | Daniel Wallner | Included in jtframe

## Known Issues

None.

Please report issues in [the issue tracker for this repository][issues].

[issues]: https://github.com/GX400-Friends/gx400-bin/issues

## Installation

Copy the `.mra` files in `/_Arcade/` and the `.rbf` file in `/_Arcade/cores/`. Then either run the `update_all.sh` script if you have it installed, or manually place the MAME ROM files (`nemesis.zip` merged, or both `nemesis.zip` and `nemesisuk.zip`, a.k.a. `nemesuk.zip`, split) in `/games/mame/`.

## Credits

* **LMN-san**
	* Twitter: [@LmnSama][]
	* GitHub: [Lmn-San][LMNSan-gh]
* **OScherler** (Olivier Scherler)
	* Twitter: [@oscherler][]
	* GitHub: [oscherler][oscherler-gh]
* **Raki** (Sehyeon Kim)
	* Twitter: [@RCAVictorCo][]
	* GitHub: [ika-musume][raki-gh]

The authors would like to thank Jotego for his amazing jtframe framework, and Sorgelig for the MiSTer project.

[LMNSan-gh]:    https://github.com/Lmn-San
[oscherler-gh]: https://github.com/oscherler
[raki-gh]:      https://github.com/ika-musume

## Support the authors

* **Raki’s Patreon**: <https://www.patreon.com/ikamusume>
* **LMN-san’s Ko-Fi**: <https://ko-fi.com/lmnsan>
* **OScherler’s Ko-Fi**: <https://ko-fi.com/oscherler>
