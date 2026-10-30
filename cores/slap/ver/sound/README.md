# Sound variants

Checks Fire/Bomb routing for both Tiger-Heli players and the existing Slap Fight
Fire/Select routing, plus all eight direction bits. Counts NMI edges over 32,768 free-running sound clock enables:
two for Slap Fight (divide by 16,384), four for Tiger-Heli (divide by 8,192).

Checks the timer reset, both A0E0/A0F0 enable writes and repeated handler writes
while the divider output is asserted. Verifies the physical 2K sound RAM aliases
throughout C000-DFFF. The CPU clock is held except during explicit register writes.

Run `simunit-all.sh --only jtslap_sound` after sourcing `setprj.sh`.
