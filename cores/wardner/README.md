# Wardner

Toaplan TP-009 / Taito B25 hardware (1987). Sets: Wardner (World), Wardner no Mori
(Japan), Pyros (US).

**Status: phases 1-5 verified in simulation; the core is assembled and lints
clean.** The DSP core and its wrapper are trace-exact against MAME, the main Z80
boots the real ROM through POST and the DSP handshake, the sound Z80 and YM3812
run, and the video engine is pixel-exact against a MAME-transcribed reference on
nine game snapshots spanning 71 seconds of the attract sequence and 72 random
ones in both screen-flip states. The whole core simulates end to end at
54.8814 Hz and its ROM layout is verified byte for byte.

A frame of the attract demo actually playing - 104 sprites over a populated
foreground layer, with the player, two enemies, a treasure chest and the HUD -
renders pixel-exact against the reference at every ROM latency from 0 to 4.

The core also makes sound: 288 keyed-on notes in the sound subsystem bench and
163 in the whole core, whose envelopes track MAME 0.289's at r = 0.95 to 0.98.
Reaching it found a real bug - `dip_test` and `tilt` were passed to the
Toaplan SYSTEM port without the inverter every other cabinet input has, so the
board saw the test switch held down and the tilt sensor tripped.

The MRA is verified: its `.rom` matches the known-good image in every region,
and generating it found the DSP region byte-reversed. The core synthesises for
MiSTer and closes timing - 61% of a 5CSEBA6U23I7's logic, 27% of its RAM
blocks - and the sprite line buffer infers as block RAM after all.

The core has been run on a real DE10-Nano and plays correctly. Getting there
found five bugs, every one of them in the layer between the emulation and
jtframe rather than in the emulation itself, and none visible to a bench that
passed: inverted MRA DIP defaults, tile ROM offsets in the wrong units, a
reversed joystick nibble, two missing cabinet-input inverters, and the pen bits
of all four graphics layers reversed against MAME's plane order. See section 19
of [`doc/plan.md`](doc/plan.md), which also covers why the frame diff reported
0 of 76800 pixels throughout.

Not yet done: the MiST and SiDi fit, which needs Quartus 13 and the Cyclone
IV E device package.

**Resuming this on another machine: read the handover at the top of
[`doc/plan.md`](doc/plan.md).** It carries the environment setup, how to
regenerate everything ROM-derived, how to run each bench, and what is left.

The board is the Flying Shark / Twin Cobra video and DSP hardware with a Z80 main CPU
in place of the 68000:

- Z80 @ 6 MHz (24 MHz XTAL / 4), banked ROM at 0x8000-0xFFFF
- Z80 @ 3.5 MHz for sound, YM3812 @ 3.5 MHz, communication via 2 KB shared RAM
- TMS320C10 DSP @ 14 MHz — required for gameplay, not just protection. It halts the
  main Z80 and drives enemy fire, collisions and sprite placement directly in the
  Z80's RAM.
- Toaplan SCU sprite controller, three 8x8 tilemaps, HD6845S CRTC
- 320x240, 54.878 Hz

See [`doc/plan.md`](doc/plan.md) for the bring-up plan, and `doc/*.cpp` for the MAME
0.289 sources this analysis is based on.
