# ROZ texel+mask interleave — focused plan

Goal: fetch a ROZ texel run and its transparency mask in one access, deleting
the separate mask port (rmask_addr/cs/ok, the 2-station miss queue, c_mbyte)
and the RMASK download relocation hack. Develop and validate on the current
BL4/64 controller first; the cps3 controller switch comes after.

Priority: no regression on in-time pixels. More out-of-time (cut) lines are
acceptable for now.

## ROM structure (what we interleave)

- ROZ texels: `c169roz` = se1_rch0 + se1_rch1, 1 MB, 8bpp. A 16x16 tile = 256
  texel bytes.
- ROZ mask: `c169roz:mask` = se1_rsh, 512 kB... but only 1 bit/texel is used:
  a 16x16 tile needs 256 mask bits = 32 bytes. (rsh is oversized/sparse.)
- Today: two separate download regions; the mask is relocated to its own
  SDRAM bank after download (the hack) to keep mask fetches off the texel
  bank.

## Access geometry (from jtc169.sv)

- texel byte addr `h_til = {code[12:0], yp[3:0], xp[3:0]}` (21b); roz_addr is
  the 32-bit word `h_til[20:2]` -> one fetch returns 4 texels.
- mask byte `h_msk = {code[13:0], yp[3:0], xp[3]}` (19b); one byte covers the
  8 texels of `xp[2:0]`.
- KEY INSIGHT: an 8-texel run and its 1 mask byte share the key
  `{code, yp[3:0], xp[3]}`. Interleaved, one tag/one line/one burst serves
  both. (Code width differs: texel uses code[12:0], mask code[13:0] - key the
  combined region on the full 14-bit code; texel side sees a sparser map.)

## RESOLVED: weave by texel key, BOTH code[13] mask bytes in the unit

MAME roz_cb sets tile=code and mask=code (full width, no masking). ROM sizes:
rch texels = 2 MB = 8192 tiles (code[12:0]); rsh mask = 512 kB = 16384 masks
(code[13:0]). So two codes differing only in bit 13 share ONE texel tile but
have DIFFERENT masks - the hardware ships 2x mask space on purpose, so bit 13
is real.

IMPLEMENTED layout (better than duplicating texels): the unit carries both
mask bytes and code[13] selects one at read time.

- unit = [4 texels][mask byte code13=0][mask byte code13=1][2 pad] = 8 bytes
- keyed by the 19-bit {code[12:0], yp[3:0], xp[3:2]}; each 8-texel mask byte
  is stored twice (once per xp[2] half), so both mask bytes ride along with
  every texel run.
- region = 2^19 x 8 = 4 MB at bank0 byte 0x400000 - exactly fills the 8 MB
  bank next to prog(1MB)+data(2MB). (Texel duplication would need 8 MB and
  not fit.) Cross-bit13 accesses share the same cache line for free.
- realized on the current controller as a 64-bit client port
  (JTFRAME_BA0_LEN=64): ONE single-burst fetch returns the texel run and
  both mask bytes. No second phase, no chained bursts, no separate mask
  path. The rmask port, the two-station miss queue, the single-entry mask
  cache, the opq opaque-tile table (fetch avoidance now buys nothing: the
  fetch always carries the mask) and the mask relocation hack are deleted.
- jtframe mem needed dw64 support in the banks model: addr_range LSB was
  dw>>4 (wrong above 32 bits) and the slot template lacked the 2'b0 pad.

A 16-byte [8 texels][2 masks][6 pad] variant with a 32-bit port and a
serialized two-phase fetch was tried first: bit-exact, but ROZ cut lines
regressed badly on minified road scenes (spd 03900: 0 -> 89). The 8-byte
single-fetch unit removes the serialization and the line thrash.

## The layout problem: power-of-2 bursts vs the 9-byte unit

The natural unit is 8 texel bytes + 1 mask byte = 9 bytes. But the current
controller bursts power-of-2 only (BL8 = 16 bytes max). 9 does not tile into
16. Two ways to live on the current controller:

- **Padded 16-byte unit**: `[8 texel][1 mask][7 pad]`. One 128-bit (BL8)
  burst returns 8 texels + their mask. Costs 2x ROZ ROM space (1MB texel ->
  2MB region) and half the fetched bytes are pad. Works today, wasteful.
  Requires roz at 128-bit (BL8) - re-introduces the burst width we reverted,
  so this path is for SIM development/validation, not necessarily to ship.
- **cps3 full-page terminate** (later): the lane bursts an arbitrary 9-byte
  run and stops. No padding, no waste. This is the interleave's real home;
  the current-controller work is to get the MRA layout and the c169 RTL
  correct in a testable place before the controller switch removes the
  padding tax.

Decision (superseded by the RESOLVED section): the shipped unit is 8 bytes
with 2 pad bytes on a 64-bit burst, so the padding tax is 25%, not 2x; the
cps3 full-page path can later drop even that.

## Download setup (MRA + make_sdram must match)

The interleave is a COARSE block weave (8 texel bytes then 1 mask byte then
pad), which stock MRA `interleave`/`frac` elements do NOT express (they weave
byte lanes across files for wide buses, not "N of A then M of B"). Options to
resolve before coding:

1. A custom mame2mra step / new region option that emits the padded weave
   from the two source regions (hardware path).
2. make_sdram.py builds the woven image directly for sim (quick, unblocks RTL
   development immediately).

Start with (2) to develop and validate the RTL, then design (1) for hardware.
Both must produce byte-identical layouts.

## c169 RTL changes

- roz lane line becomes 128-bit; the fetch returns `{pad, mask_byte, 8 texel
  bytes}`.
- texel read: `h_tex` selects its byte from the low 8 (unchanged logic, new
  source).
- mask read: `h_mbit` selects from bit `~xp[2:0]` of the mask byte in the
  same fetched line - NO separate fetch.
- DELETE: rmask_addr, rmask_cs, rmask_ok, rmask_data port; the second-station
  mask miss queue (mo/mbl/rmask_addr paths); c_maddr/c_mbyte mask cache. The
  opq (opaque-tile skip) table interaction stays but now gates on the same
  combined line.
- The address the roz lane issues is the combined-region address derived from
  `{code, yp[3:0], xp[3]}`.

## Validation gate

1. burst_07200 + a road scene (05400/06000) fingerprint: in-time pixels must
   be identical to today (the mask bit resolves to the same value, so the
   drawn image is unchanged). This is the hard no-regression check.
2. SYSFL_ROZDBG cut/wait on the road scenes: cuts may rise (2x fetch volume);
   record how much. Acceptable per priority.
3. Both games scene sweep + gameplay boot, 0 errors.

## Sequence

1. make_sdram.py weaves the padded roz+mask image (sim only). DONE
2. Rewire c169 to read mask from the roz unit, delete the mask port. DONE
3. 64-bit roz port on the current controller (BA0_LEN=64, dw64 lcache). DONE
4. Validate (gate above). Iterate until in-time pixels are bit-exact.
5. Design the MRA/download weave for hardware (mame2mra + the game.v opq
   builder must move to the woven region; RMASK_START download becomes dead).
6. Later: controller switch to cps3; drop the padding via full-page bursts.
