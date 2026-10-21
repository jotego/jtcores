# Shared-core lint triage

ROOT observed compatible lint session63541 terminate with exit1. Of98 core logs,25 complete lint,12 skip,59 stop on missing dependency inputs, and cal50/thundr stop on absent `rest.bin`. No Verilator `%Error` or `%Warning` occurs, and no diagnostic names the four changed JT51 files. Generic missing-DIP notices and eight memory-generator notices remain distinct from Verilator diagnostics. This is a limited integration result, not a clean lint-all claim.

18 configured JT51 consumers complete lint: blkout, contra, cps1, dd, dd2, fround, grad3, mx5k, outrun, riders, s16, s16b, sf, shouse, tmnt, twin16, vigil, wwfss. Their manifest loads the candidate source set, including EG/MMR/noise/timers. DD2 inherits DD's common manifest; S16B inherits S16. QSound-only CPS15/CPS2 successes are excluded.

11 JT51 consumers remain blocked: 88game, ajax, aliens, biocom, harier, prmr, simson, taitox, thundr, toki, tora. NARC is skipped. Missing dependencies are outside the JT51 correction. Protected JTOPL staged deletions and other user dirt are preserved; nested JT12 JT49/JT89 submodules remain uninitialized. No dependency repair was attempted.

The first unadapted run's86 failures divide into59 missing dependency inputs and27 unsupported `--quiet-stats` failures. The compatibility shim removes only that exact flag and delegates to the same installed Verilator. Both initial and compatible outputs remain pinned in the JSON report. The two extra compatible blockers are cal50's `rest2bin.sh:11` and thundr's `ver/rest2bin.sh:2..5`, each requiring missing `rest.bin` data.
