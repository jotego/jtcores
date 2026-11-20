# Palette and source-tag pipeline

Exercises the synchronous palette RAM, the real `jtnemsis_main` registered RGB
output, the game-equivalent pixel source capture, `jtframe_blank`, and the real
one-clock colmix LUT with alternating tile A/B pixels. The test keeps only the
main module's measured CPU logic disabled (`NOMAIN`); its live RGB register is
the production RTL.
