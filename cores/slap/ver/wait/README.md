# Video RAM wait circuit

Checks the schematic sheet 8 two-stage LS74 wait chains for both layers,
all eight pixel phases, scroll phases and both flip states. WAIT must assert
on selection, last for two falling graphics-clock edges, and release when
the access ends.

Run from the repository root after sourcing `setprj.sh`:

```
simunit-all.sh --only jtslap_wait
```
