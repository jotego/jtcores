- JTSHARRIER

Sega Space Harrier compatible verilog core for FPGA, built on JTFRAME
(https://github.com/jotego/jtframe) and reusing HDL from Jose Tejada's jtcores.

Space Harrier runs on Sega's Hang-On hardware: two 68000s, an i8751 MCU, a Z80
for sound, a YM2203 and the discrete SegaPCM part, plus the tilemap, sprite and
road generators shared with Hang-On and Enduro Racer. That hardware uses the
same video chips as System 16A, so the tilemap and palette come from jts16.

- Supported Games

Set        | Description                           | Notes
-----------|---------------------------------------|--------------------------------
sharrier   | Space Harrier (Rev A, 8751 315-5163A) | Preferred. Clean MCU dump.
sharrier1  | Space Harrier (8751 315-5163)         | MCU is flagged BAD_DUMP in MAME

Use the Rev A set where possible. The MCU drives the 68000's interrupt lines and
gates the boot sequence, so a bad MCU dump matters more here than it would
elsewhere.

- Controls

Space Harrier is an analog game. The cabinet has a sprung flight stick and three
fire buttons that all do the same thing; the game reads the stick through an
ADC0804, and the i8751 MCU does the reading, not the main CPU.

Note that Analog stick is the intended control.
D-pad is supported as an option, but the game has no concept of a digital
input, so the pad is converted to a position internally.

The cabinet's stick is an aircraft stick: push up and Harrier goes down.

- QOL Options

Beyond the DIPs, three options are added. All default to the arcade
behaviour, so loading the MRA and changing nothing gives you the original
machine.

Option          | Values           | Default | What it does
----------------|------------------|---------|--------------------------------------
Stick Direction | Normal / Arcade  | Arcade  | Y-axis inversion. Arcade matches the cabinet's aircraft stick.
D-Pad Control   | Console / Arcade | Arcade  | How the d-pad behaves on release. See below.
V Glyph Fix     | On / Off         | Off     | Corrects a glyph drawn wrong in the original ROM. See below.

- The 'V' glyph

The letter "V" is drawn wrong in the original ROM: it rolls over by one, so the
bottom border appears at the top. This is authentic. It looks the same in MAME
and on real hardware. It shows in the test menu and on the scoreboard name
select.

The core is faithful by default. Turning the option On renders a normal V.

- D-Pad Control, and why Arcade is the default

Arcade springs the stick back to centre on release, like the real cabinet.
Basically unplayable with a pad. Console
leaves Harrier where you let go, as the home conversions do.

Arcade is the default for a safety reason also. The two
input paths are summed, so if you are playing with an analog stick and
brush the d-pad in Console mode, that offset stays applied to every reading
afterwards, so your stick's physical centre now maps somewhere else. Arcade
mode decays it away.

- Accuracy Notes

Developed and checked against my original Space Harrier cabinet and known-good
PCBs (Retro Clinic), and Mame. The flight stick calibration, boot timing,
road position, sound balance and video timing were all measured from my Cab.

Game speed was measured against the cabinet over a 30 minute synchronised
recording. The core runs about 0.16% fast, roughly 2.9 seconds in half an hour - 
and thats fine.
The schematics were used throughout where possible. The audio
mixing is built from the board's own summing resistors and filter values read
off the sound board sheet. The PPI port assignments,
including the sound CPU reset line, were traced on the schematic and checked
against MAME rather than taken on trust.

Known and not fixed:

- A certain sound effect later in the game can stick on for a while under
  heavy activity; this is most likely original behaviour.

- Provenance

Subsystem                          | Source
-----------------------------------|----------------------------------------
68000 x2, i8255 PPI, YM2203, mixer  | JTFRAME (jotego)
Tilemap, palette, priority          | jts16 (jotego)
SegaPCM                             | forked from jtoutrun (jotego)
i8751 MCU                           | Oregano mc8051 (LGPL), retimed here
Road generator                      | transcribed from MAME segaic16_road.cpp
Sprite scan and draw                | transcribed from MAME sega16sp.cpp
Memory map, I/O, ADC, sound, video  | written for this core

The road and sprite routines are the two places where MAME's C++ was read and
re-implemented in verilog. Everything else is either jotego's HDL or new work.

MAME was used for those two because Space Harrier's road and sprite hardware are
their own variants, and no existing jtcores core implements them. Sega's custom
chips have never been decapped, so there is no die shot to work from. MAME's 
implementation is the best available description of what they do.

Out Run's sprite zoom enlarges; Space Harrier's only ever shrinks, because the
sprite ROM holds many pre-scaled copies of each object and the hardware
interpolates between them. Porting Out Run's drawer was tried first and came out the wrong
shape, so MAME's description of the actual part was used instead. The road is
the same story: Out Run's generator is a different one.

- Credits and Licence

This core is GPL-3, as JTCORES is.

- Built on JTFRAME and the jts16 / jtoutrun HDL by Jose Tejada (jotego).
  Tilemap, palette, priority, 68000, i8255, YM2203 and the SegaPCM module all
  come from his work. Please support it: https://patreon.com/jotego
- The 8051 core is Oregano Systems' mc8051 (LGPL), via JTFRAME.
- The road generator and the sprite draw routine are transcribed into verilog
  from MAME's segaic16_road.cpp and sega16sp.cpp, BSD-3-Clause, copyright
  Aaron Giles. Attribution is retained in those module headers.
- Space Harrier core work by niknak.
- HDL, simulation analysis and documentation written in collaboration with
  Claude (Anthropic). Hardware measurement, testing and the judgement calls
  on the result were niknak's.