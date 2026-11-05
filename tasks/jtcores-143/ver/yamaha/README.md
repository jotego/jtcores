# Yamaha serial sampler

Checks full 16-bit SO words (including the three unspecified low bits), channel
ordering, alternating fractional 55/56-clock bit cells, input inversion, clear,
missing clocks and repeated SH edges. Run after sourcing root `setprj.sh`:

```
simunit.sh --run tasks/jtcores-143/ver/yamaha
```
