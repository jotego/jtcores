# Pocket button defaults

Run `simunit-all.sh --only jtframe_pocket_joystick` from the project root after
sourcing `setprj.sh`.

The test writes the Pocket configuration registers using independent host,
ROM, and system clocks. It checks reset identity routing, all four players,
Y/X/A directional buttons, L/R shoulders, unused inputs, and a subsequent
identity write when switching to a game without a custom map. It also checks
that unrelated configuration writes, directions, upper controller bits, and
analogue inputs retain their existing behavior.
