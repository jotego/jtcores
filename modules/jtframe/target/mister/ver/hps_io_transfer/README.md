# MiSTer HPS transfers

From the worktree root, source and pin its build paths, then run
`modules/jtframe/target/mister/ver/hps_io_transfer/sim.sh local`:

```sh
set --
source ./setprj.sh >/dev/null
export JTROOT="$PWD" JTFRAME="$PWD/modules/jtframe" CORES="$PWD/cores" MODULES="$PWD/modules"
export JTBIN="$PWD/release" RLS="$PWD/release" MRA="$PWD/release/mra" ROM="$PWD/rom"
export PATH="$JTFRAME/bin:$PATH"
unset JTCORE_DEFAULT
modules/jtframe/target/mister/ver/hps_io_transfer/sim.sh local
```

This exercises the real `hps_io` module in byte and word modes,
connected to the real `jtframe_mister_dwnld` wrapper. The test checks deferred
activation, the initial upload read at its requested address, subsequent read
and write address stepping, low-byte data delivery, the final one-past address,
registered address-dependent upload data, complete WIDE download words, HPS
wait handling, one/multiple item transfers, and zero/nonzero empty-download DDR
length behavior.

Run the same script with `baseline` for a negative control against rebased
baseline `9cb695ac1`; it passes only when the old implementation fails the first upload
address check. The test uses standalone Verilator because the standard simunit
runner's Icarus compile rejects the existing forward reference to `ddram_wait`
in `jtframe_mister_dwnld.v`. It is kept out of `.simunit` so CI does not report
an unusable test as passing.
