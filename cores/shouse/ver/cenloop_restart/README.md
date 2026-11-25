# jtshouse_cenloop restart

Two `jtshouse_cenloop` instances leave reset at different times. The test
checks that the main, sub, MCU and sound clock enables follow the same pattern
counted from the reset release. Before, the CPU rotor and the fractional
counter ran through the reset, so which CPU got the first pulse depended on how
long the reset lasted.
