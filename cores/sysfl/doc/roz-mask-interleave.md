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

## RESOLVED: weave by mask key, texel duplicated across code[13]

MAME roz_cb sets tile=code and mask=code (full width, no masking). ROM sizes:
rch texels = 2 MB = 8192 tiles (code[12:0]); rsh mask = 512 kB = 16384 masks
(code[13:0]). So two codes differing only in bit 13 share ONE texel tile but
have DIFFERENT masks - the hardware ships 2x mask space on purpose, so bit 13
is real. Therefore:

- The woven region is indexed by the full mask key h_msk =
  {code[13:0], yp[3:0], xp[3]} (this IS the 8-texel group index).
- The texel group for code and code+8192 is DUPLICATED (stored twice).
- Region size at the padded 16-byte unit: 16384 tiles x 32 groups/tile
  (16 rows x 2 xp[3]) x 16 bytes = 8 MB. (Texels duplicated + mask + pad.)
  Fits SDRAM; the cps3 full-page path later drops the 7-byte pad to ~4.5 MB.

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

Decision: develop with the padded 16-byte unit on the current controller
(sim-provable, no in-time regression), knowing the cps3 switch later drops
the pad. Sim measures whether the 2x ROZ fetch volume costs cut lines - the
budget we said we can spend.

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

1. make_sdram.py weaves the padded roz+mask image (sim only).
2. Rewire c169 to read mask from the roz line, delete the mask port.
3. roz lane -> 128-bit on the current controller.
4. Validate (gate above). Iterate until in-time pixels are bit-exact.
5. Design the MRA/download weave for hardware.
6. Later: controller switch to cps3; drop the padding via full-page bursts.
