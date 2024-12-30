# NGP Pocket simulations

- Loading firmware+nvram+1MB flash takes 45 frames
- There is a language/time setting menu which lasts for ~706 frames. Use -inputs
to get the right key presses to get through it
- The NeoGeo logo animation after the settings lasts for ~479 frames. It can be skipped by holding button B.
- Overall, loading, setting menu and NeoGeo logo is about ~1215 frames. The logo
becomes static at frame 1148
- cart size should be loaded
- simplify the trace to load it in a text editor
> sed s/XWA1=0,XBC1=0,XDE1=0,XHL1=0,XWA2=0,XBC2=0,XDE2=0,XHL2=0,// debug.trace > view.trace

To compare MAME with the core, the RTC timer values must be equal. If the simulation skips the setup stage (by using an NVRAM file), the timer start up values must be set with the macro `JTFRAME_SIM_RTC=n`, where n is a hex number containing hour-min-sec. It is enough to set the seconds. The number required is usally between 5 to 9, depending on how quickly you go through the menu in MAME.

# BaseBall Stars

Use `sim.sh -nvram -cart carts/Baseball\ Stars\ \(JE\)\ \(M2\).ngp`

- 190 frames to finish the NeoGeo logo
- 274 frames to display the game logo

## Firmware Hack

In order to synchronize MAME traces with simulation, some instructions are
modified for a NOP+HALT combination, so the interrupts happen at the same time.

| ADDR   | Original | Modified         | Remarks                   |
| ------ | -------- | ---------------- | ------------------------- |
| FF1D76 | 66 11    | 00 05  NOP, HALT | ADC reads before frame 27 |
| FF4701 | 67 F9    | 00 05            | Loop after config         |
| FF8A22 | 66 F8    | 00 05            | Loop after logo           |

## Scene simulations

Run mame in debug mode and save a scene with `save vram.bin,8000,4000`. Then move the vram.bin file to a new folder in ver/game/scenes.