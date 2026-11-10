# Automatic aiming activation

Run `simunit-all.sh --only jtcps1_main` after sourcing the project environment.
The test drives the main CPU I/O bus and checks all 256 signed values on each
right-stick axis for both players. It verifies the dead zone (-23 through 23),
frame sampling, independent activation, coordinate reads, latching at center,
and clearing both modes on reset. The CPU bus is held by the testbench; no game
ROM is needed. The Forgotten Worlds assembly and gameplay tests are in
`../forgottn/test-aim.sh`.
