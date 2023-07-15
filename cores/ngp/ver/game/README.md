# NGP Pocket simulations

- Loading firmware+nvram+1MB flash takes 45 frames
- There is a language/time setting menu which lasts for ~706 frames. Use -inputs
to get the right key presses to get through it
- The NeoGeo logo animation after the settings lasts for ~479 frames
- Overall, loading, setting menu and NeoGeo logo is about ~1215 frames. The logo
becomes static at frame 1148
- cart size should be loaded

## Firmware Hack

In order to synchronize MAME traces with simulation, some instructions are
modified for a NOP+HALT combination, so the interrupts happen at the same time.

ADDR   | Original  | Modified           | Remarks
-------|-----------|--------------------|----------
FF1D76 |   66 11   | 00 05  NOP, HALT   | ADC reads before frame 27
FF4701 |   67 F9   | 00 05              | Loop after config
FF8A22 |   66 F8   | 00 05              | Loop after logo