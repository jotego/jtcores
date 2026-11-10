# Nemesis Z80 ROM wait test

Exercises the real T80s CPU with the 67/1840 JTFRAME gated clock enable and the production `jtframe_romrq_bcache` configured with `OKLATCH=1`. A two-beat mock SDRAM responder supplies the cache line after deterministic 0–31-cycle waits and forced 175-cycle refills. The bench checks ROM bytes consumed by the CPU and compares twenty RAM-write bytes against a no-stall run. It reports the number of forced long refills, CPU ROM reads, and minimum CEN spacing. The cache's ready/data behavior is modeled by the actual RTL; the bench does not inject an artificial stale wrong byte.

Run from the repository root after sourcing `setprj.sh`:

```sh
simunit.sh --run cores/nemsis/ver/sndwait
```
