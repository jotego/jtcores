# System FL: hardware flashing after a bank reshuffle — investigation report

Audience: upstream (jtframe). Everything below was bench-tested on a MiSTer
(DE10-Nano, 128MB dual-chip SDRAM module) at the core's 54.000 MHz single
clock, with the same ROMs and the matching MRA deployed for every build.
Sims (Verilator, scene replays plus a 500-frame coin boot) pass on every
single one of these builds: all the failures below are hardware-only.

## Symptom

Video blinks (black frames at a fast rate), player inputs dead, the TEST
input seen by the game toggles by itself (test menu opens and closes), the
games' own ROM tests pass everything. Both speedrcr and finalapr, always.

## Build/verdict history

| build | banks | verdict |
| --- | --- | --- |
| `1948a3046` | classic: b0=main+roz, b1=obj(64), b2=scr+smask+mcurom, b3(rw)=wram+pcm+rmask+wram32 | GOOD |
| `6edf7982f` | same tenants, `JTFRAME_SDRAM_LARGE`, 16MB-spaced starts | BAD |
| `0d53321d2` | same tenants, plain 32MB, starts moved to 8MB boundaries | GOOD — region moves acquitted |
| `5d913b951` | reshuffle: b0(rw)=wram+main+wram32+smask+rmask, b2(64)=scr+roz+mcurom, b3=roz2+pcm, `BA3_LEN` 16/32 | BAD |
| `672a501ec` | + cen-aligned IRQ latches, held ic_clr (CPU multicycle hardening) | BAD |
| `45b5823e2` | + the SLOT_DOUBLE template fix (below), `BA3_LEN` removed | BAD |
| `b02a7ef1c` | + mcurom back on a 32-burst bank | BAD |
| `95b281ae0` | + rw bank stripped of every cached slot (main+masks+mcurom to an all-ROM bank 0, wram cluster to bank 3, roz2 uncached) | **flashes noticeably less, still unusable** |

The good/bad boundary is the bank reshuffle itself, not the region moves,
not the CPU timing waivers, and only partially the two concrete bugs found
along the way.

## Confirmed upstream bug found during the hunt: SLOT_DOUBLE on short banks

`hdl/inc/game_sdram.v` emits, for every bank:

    `ifdef JTFRAME_BA{bank}_LEN
        ,.SLOT{i}_DOUBLE(1)   // every non-rw bus of the bank
    `endif

keyed on the macro EXISTING, not on its value being 64. DOUBLE makes
`jtframe_romrq_bcache` collect four data beats; a bank defined with
`BAx_LEN=16` or `=32` strobes fewer, so the first read on any UNCACHED bus
of such a bank hangs forever. In sysfl that bus was pcm: the C75/M37702's
first PCM fetch wedged the MCU — dead inputs, floating TEST, per-frame
handshake failure — while the i960-side ROM tests stayed green. Boot sims
never play a voice, so simulation is blind to it. Cached buses are immune
(the lcache ignores DOUBLE), which is why no shipping core has hit it: the
combination needs an uncached bus on a bank that explicitly defines a
non-64 length, and 32 being the parameter default, nobody defines it.

Suggested fix: emit the parameter from the value (`==64`), and/or make
bcache assert in simulation when DOUBLE is set and a burst ends early.

Fixing this on sysfl was necessary but not sufficient: the flashing
persisted, so the core also carried a second, still-unpinned problem.

## The remaining suspect space

After `95b281ae0` the symptom weakened but did not clear. What that build
still carries versus the known-good layout:

1. **scr (DW=8) and roz (DW=32, non-LINE2X) cached buses on a
   `BA2_LEN=64` bank.** With `JTFRAME_CORE_LCACHE`, these run lcache
   output arms (`gen_byte/gen_burst64`, `gen_long/gen_burst64`) that no
   core had ever run on hardware; every proven configuration uses these
   widths at burst 32, or objrom's LINE2X shape.
2. The partial improvement from removing the cached slot out of the rw
   bank suggests **a `CACHE_LARGE` slot inside `jtframe_ram1_Nslots`**
   (also a first: other cores' rw-bank `main 1kB` caches are the stock
   kind, not CORE_LCACHE) contributes its own failure mode.
3. Core-local changes present in all bad builds (a second ROZ bus with a
   per-line steep select; the opq table's download window following the
   rmask region) — considered unlikely by construction, and the second
   ROZ bus is retired regardless.

We stopped the bisect here: sysfl returns to its proven bank layout and
drops the second ROZ copy. The practical lesson for jtframe is that the
never-exercised corners of the bank/cache generator space (LARGE at LF,
short explicit lengths, 64-burst lcache arms, cached slots in rw banks)
fail on hardware while passing every behavioral simulation, because the
failure modes live in protocol corner cases the models idealize (burst
truncation, beat counting) — a self-checking rw/burst test per generated
configuration would catch this class before the bench does.

## Reproduction

Any of the BAD commits above on branch `nsr` of this fork, built for
mister with its generated MRA (the region starts move between builds, so
the rbf and MRA must be deployed as a pair). GOOD/BAD pairs one commit
apart isolate each variable; `0d53321d2` vs `5d913b951` is the cleanest
overall A/B.
