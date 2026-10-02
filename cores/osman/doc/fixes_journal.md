# Osman — fixes journal

## HW test #1: joystick directions scrambled + okimusic is noise

Two independent bugs from the first MiSTer test (SFX was fine, music was noise, dirs wrong).

### 1. Joystick directions scrambled (up reads as right)

**Root cause:** no `JTFRAME_JOY_*` macro in macros.def. JTFRAME's default joystick order is
up,down,left,right on [3:0] (i.e. [3]=up ... [0]=right), but simpl156's IN1 wants MAME's
U/D/L/R at bits 0-3 (b0=up, b3=right). With no reorder the raw bits go straight to IN1, so
pressing up lands on bit3 = right (and down<->left).

**Fix:** `JTFRAME_JOY_RLDU=1` — jtframe_joy_reorder bit-reverses [3:0]. Same macro cninja /
karnov / cop / cal50 use. Removed the "(joystick bit order TODO if dirs wrong)" note in main.

### 2. okimusic played noise (SFX fine)

**Root cause:** the OKI status read was still HLE'd to 0 — a leftover from before jt6295
existed, with its own note: "no jt6295 yet -> HLE as IDLE (0) ... TODO remove when jt6295
lands." The jt6295s landed but the HLE stayed, and `.dout()` was left unconnected. okim6295
reads return {4'hf, per-channel busy}; the music sequencer polls it to know when a phrase is
done. Always reading 0 (= idle, and high nibble 0 instead of 0xf) makes it re-trigger the
phrase forever -> noise. SFX is fire-and-forget, so it was unaffected — exactly the observed
split.

**Ruled out first (all verified correct, don't re-chase):** the okimusic address descramble
(`rom2_addr={A[19:0],A[20]}` — checked against a python model of MAME's bitswap over the real
mcf-05: 0 mismatches, and the descrambled bank0 OKI phrase table is 8/8 sane vs 0/8 raw); the
ROM blob (okisfx @0x280000 and okimusic @0x2C0000 are byte-exact in osman.rom); the bank map
(okimusic 0x2C0000..0x4C0000 fits BA2 exactly); the >>1 word-unit PCM offsets (same as cninja);
and the 1 MHz okimusic clock (mitchell156() line 557 does override to 28MHz/28).

**Fix:** expose `oki1_dout`/`oki2_dout` from jtosman_snd, wire them through game.v, and return
them from main on okisfx/okimusic reads instead of 0.

**Lesson:** the sim audio check that passed this was envelope-only (game-time energy
cross-correlation 0.917) — a constantly re-triggered phrase has roughly the right envelope but
is noise. Grade audio on the WAVEFORM, not the envelope.

Commit: "osman: fix joystick bit order + okimusic noise (OKI status read was HLE'd to 0)"

## MiSTer synthesis fails: eeprom_osman.hex missing from the repo

**Symptom:** After the SEARCH_PATH fix, `compile-one` (mister) got past the amber includes and
elaborated, then failed with
`Error (10054): can't open Verilog Design File "eeprom_osman.hex"` at jtosman_main.v:151 and
`Error (12152): Can't elaborate user hierarchy ...|jtosman_main:u_main`. Local sim/lint were clean.

**Root cause:** `.gitignore` line 11 ignores `*.hex`, so `cores/osman/hdl/eeprom_osman.hex` was
never committed — it only ever existed in the local working tree. The CI clone therefore had no
such file. This is NOT a sim-only asset: osman/candance do not initialise their own EEPROM
(word[0]=0xffbe, word[0x20]=0x0088 must be present or the game won't boot, per simpl156.cpp), so
`initial $readmemh("eeprom_osman.hex", eegold)` preloads the jt9346 through its dump port at
power-up — Quartus needs it at synthesis to initialise the BRAM.

**Fix:** `git add -f cores/osman/hdl/eeprom_osman.hex` (64 words; word[0]=ffbe, word[0x20]=0088),
the same force-add already used for the deco56_{address,xor,swap}.hex tables. Longer term the TODO
in jtosman_main.v still stands: source the EEPROM image from the MRA eeprom region (hardware NVRAM
path) instead of a readmemh preload, which would also cover the candance image.

Commit: "osman: track eeprom_osman.hex — gitignored *.hex broke MiSTer synth"

## MiSTer synthesis fails: Quartus can't find the amber/ include fragments

**Symptom:** `compile-one` (mister) fails in Analysis & Synthesis with a wall of
`Error (10054): can't open Verilog Design File "amber/a23_localparams.v"` (also a23_functions.v,
a23_config_defines.v, memory_configuration.v, debug_functions.v), plus a cascade
`Critical Warning (10191): text macro "A23_CACHE_WAYS" is undefined` → `Error (10170)` at
a23_cache.v:66 (A23_CACHE_WAYS lives in the a23_config_defines.v that failed to open). Lint/sim
are clean — the failure is Quartus-only.

**Root cause:** the vendored Amber ARM (`hdl/amber/`) uses `` `include "amber/<file>" `` for its 5
config/localparam fragments. The Verilator sim resolves these via jtsim's `-I cores/osman/hdl`, but
the MiSTer qsf only sets `SEARCH_PATH "../hdl"` + `$JTFRAME/hdl/inc` — neither covers
`cores/osman/hdl`, so Quartus never finds `amber/…`.

**Fix:** added `cores/osman/syn/osman.qip` that puts the core's hdl dir on the Quartus search path
from its own location — `set_global_assignment -name SEARCH_PATH [file normalize [file join
$::quartus(qip_path) .. hdl]]` (the qip sits in `syn/`, so `../hdl` = `cores/osman/hdl`). Listed it
in `cfg/files.yaml` (a `.qip` get resolves to `syn/` and jtframe emits it as `QIP_FILE`; the sim
`game.f` skips `.qip`, so lint/sim are untouched). Verified: `jtframe files syn osman
--target=mister` emits the `QIP_FILE` line and the Tcl resolves to `/jtcores/cores/osman/hdl`.

Commit: "osman: fix MiSTer synth — add hdl/ to Quartus SEARCH_PATH for amber includes (syn qip)"

## Sound board: 2× OKI M6295 (jt6295) driven by the main ARM

**What:** Replaced the `jtosman_snd` scaffold stub (outputs tied to 0) with two `jt6295`
instances — `okisfx` (SFX/voice) + `okimusic` (music) — driven directly by the ARM, no
sound CPU. Modeled on pang's `jtpang_snd`. Both run at 28 MHz/28 = 1 MHz with PIN7 HIGH
(mitchell156: `okimusic` overridden to /28), so `ss=1`. `oki?_wr` from the main are 1-clk
pulses → `wrn = ~oki?_wr` (jt6295 captures on `negedge_wrn` at clk resolution, not cen). ROM
cs tied high (jt6295 fetches continuously). INTERPOL=0 (no interpolator hex needed), matching
pang and MAME (which doesn't interpolate).

**okimusic banking + descramble:** `set_rom_bank(data&0x7)` → `oki2_bank[2:0]` prepended to
the OKI's 18-bit address = 21-bit A. init_simpl156 permutes the ROM at load
(`buf1[bitswap<24>(x,23,22,21,0,20,19..1)] = rom[x]`), moving the true low address line up to
bit 20 ("low line goes to the banking chip"). The SDRAM holds the raw ROM, so the read address
gets the inverse: `rom2_addr = {A[19:0], A[20]}`. Done on the read side in the sound module,
not in the download post_addr.

**How verified:** Captured MAME's attract audio (regenerate: `mame osman -wavwrite ref.wav
-seconds_to_run 30`); ran the FPGA sim with sound. Game-time-aligned envelope cross-correlation
= **0.917** — both silent ~18s,
both burst at t≈19-25s. Relative channel mix (okisfx:okimusic = 3:1) matches MAME's 0.6:0.2
routing (mem.yaml rsum 20k:60k). Caveats (not core bugs): the host lacks `raw2wav` so the sim
wav is written at the internal rate mislabeled 48 kHz (time-stretched ~2.7×); absolute level is
~2× low — an overall-gain calibration best tuned on hardware.

Commit: "osman: sound board — 2x jt6295 (okisfx+okimusic) driven by the ARM"

## Sprite priority: pri-1 sprites drawn over pf1 instead of behind it

**Symptom:** In the dragon boss attract scene (burst_01500/01800/02100), the dragon's lower
coils were drawn *over* the desert foreground dune; in MAME the dune (pf1) occludes them.
Scene grade 01500 mean 15.4, 3960 big-diff px, all in the bottom-right dune band.

**How we found it:** Ruled out tilemaps (pf1 isolated — it holds the dune; pf2 the background)
and dropped sprites (LINEMAX bump = no change; live-MAME sprite dump = all 138 sprites pri 0/1,
zero pri 2/3 — dump faithful). Blanked MAME's tilemaps via Lua (`write_u32 0` over 0x1d0000-
0x1d5fff) to get a sprites-only render: the dragon coil IS present at the same position as the
FPGA. So placement was right and the dune (pf1) was occluding a pri-1 sprite. That is only
possible if pri 1 sits *behind* pf1 — contradicting our mux, which put pri 0 and pri 1 both in
front.

**Root cause:** Misread the drawgfx priority test. simpl156 draws pf2 into the priority bitmap
with value 2 and pf1 with value 4, then `draw_sprites` uses `prio_transpen`, whose test is
`(pmask & (1 << pri_bitmap_value)) != 0 => occluded` — the bitmap value is a **shift amount**,
not a direct mask. With pri_callback pmask `1->0xf0`: `1<<4=0x10` hits pf1 (occluded) but
`1<<2=0x04` misses pf2 (drawn). So pri 1 = behind pf1 / front of pf2, NOT front of both. The
colmix had split on `obj_pxl[10]` alone (pri 0/1 → front, 2/3 → mid), collapsing the pri-0 vs
pri-1 distinction.

**Fix:** `jtosman_colmix.v` — split on the full 2-bit pri: pri 0 front of all; pri 1 between
pf1 and pf2; pri 2/3 behind both playfields (new `obj_back` branch below pf2, above backdrop).
All 15 scenes re-graded: mean 2.6 → 0.84; 01500 15.4 → 1.98, 9 scenes pixel-identical.

Commit: "osman: fix sprite priority — pri-1 sits behind pf1 (drawgfx 1<<pri mask semantics)"

## deco16ic tile bank truncated to 1 bit → entirely wrong pf tiles

**Symptom:** With the scene-replay grader (BEST-10 / burst_02100), the pf2 background
rendered the wrong tiles entirely — right gfx, right palette, but the wrong tile *codes*
pulled per screen position (the sun, rock and desert were scrambled/absent).

**How we found it:** Graded the FPGA vs MAME's captured scene. The tiles+palette were
correct, so the fault was the code→gfx mapping. Read simpl156's deco16ic bank callback:
`return ((bank>>4)&7)*0x1000` — a bank of up to 3 bits added to the 12-bit tile code
(`tile & 0xfff + m_pf1_bank`). For the scene `control[7]=0x3121`: pf1 bank=2 (+0x2000),
pf2 bank=3 (+0x3000). From the scene dump, pf2 tile[0]=0x327a → MAME gfx 0x327a, but the
FPGA fetched 0x127a — because `jtframe_deco16.roma16` used only `bank[0]`.

**Root cause:** `jtframe_deco16` (cninja) hard-codes `roma16 = {bank[0], code[11:0], ...}` —
a single bank bit (cninja passes `.bank({2'd0,bg_bank})`, so it never needed more). Osman's
deco16ic uses 2 bank bits (bank 0-3), so bank[1] was dropped and every banked tile fetched
0x1000 tiles too low.

**Fix:** Parametrized the bank width in `jtframe_deco16` — `parameter BANKW=1` (default keeps
cninja bit-identical), `roma16/roma8 = {bank[BANKW-1:0], code, ...}`, `rom_addr[BANKW+18:2]`.
Osman instantiates with `.BANKW(2)`; its gfxdec + roma wires widen to a 19-bit render addr.
pf2 background now matches MAME (sun/rock/desert). cninja lints clean (BANKW=1 unchanged).

Commit: "osman: fix deco16ic tile bank — jtframe_deco16 BANKW param (was 1-bit, osman needs 2)"

## Tilemap missing right 48px + 1px X misalignment (scene-graded)

**Symptom:** After the bank fix, the pf2 background was correct but (a) the right ~48px
were black and (b) everything sat 1px right of MAME.

**How we found it:** Scene grader. The FPGA render's rightmost lit column was logical 272
(= 34×8), and a brute-force offset search vs MAME's screen.png found a clean minimum at
dx=-1,dy=0 (mean diff 31→13.5).

**Root cause / fix:**
- Right band: `jtframe_deco16` hard-capped the line at 34 8px-columns (`colcnt>=33`) — a
  cninja 256px constant. Added `parameter COLS` (default 34); osman uses COLS=42 (320px).
- 1px X: constant tilemap-vs-visarea offset. Added `HOFS=1` to both layers' scrollx in
  jtosman_video. Re-graded: offset search now bottoms at dx=0,dy=0 (pixel-aligned).

pf2 background is pixel-exact vs MAME's BEST-10 scene. Remaining diff = the sprite layer
(BEST 10 text + flaming rider), not yet implemented.

Commit: "osman: fill full 320px width — jtframe_deco16 COLS param (cninja 34 -> osman 42)"
Commit: "osman: 1px tilemap X align (HOFS) — pf2 now pixel-exact vs MAME scene"

## Sprites render (plane-pack + pswap)

**Symptom:** First-pass sprite wiring drew garbled color at roughly the right positions.

**Root cause / fix (scene-graded on BEST-10):**
- Plane-pack: sprite gfx is 8 MB RGN_FRAC(1,2) (FRAC0=planes 2,3; FRAC1=planes 0,1), fed raw.
  Added a BA3 post_addr rotate `{prog_addr[20:0], ~prog_addr[21]}` to interleave the two 4 MB
  halves into each 32-bit word (FRAC1->low16, FRAC0->high16). Region fills the 8 MB slot -> no
  fold-back. Shapes then correct (chains/rider/flames placed right) but colors wrong.
- Plane bit-order: colors wrong (green flame, blue chains) = plane pairs swapped. `pswap=1` on
  jtframe_decospr fixed it — white chains, red flames, purple rider all match MAME.

Remaining: sprites sit a few px too low (Y offset / set_flip_screen handling) and the "BEST 10"
text is absent (decospr scans 256 sprites; osman draws 320).

Commit: "osman: sprite plane-pack (BA3 FRAC interleave) + pswap — sprites match MAME"

## deco16ic: each pf draws ONE size (8x8/16x16), not both — control1[7] gates it

**Symptom (user-spotted):** the added 8x8 tilemap layer painted opaque yellow where it
should be transparent, covering the sky.

**Root cause:** deco16_pf_update (deco16ic.cpp) sets `tilemap_8x8->enable(control1[7]?..:0)`
and `tilemap_16x16->enable(control1[7]?0:..)` — so per playfield only the size selected by
control1[7] is drawn; the other is DISABLED (transparent). The 4-layer WIP drew both
unconditionally, so the (disabled-in-MAME) 8x8's empty tiles — code0 + the pf bank -> an
OPAQUE pen -> yellow — covered the 16x16. For the BEST-10 scene both pf are 16x16.

**Fix:** gate each size's pixel by control1[7] in jtosman_video (pf?a active when
control1[7]==0, pf?b when ==1). Scene restored: sky/rock/sprites correct, no yellow.
The 4-layer structure stays for scenes that DO select 8x8.

Remaining: the "BEST 10"/score text is the SPRITE layer (not a tilemap) — top-of-screen
sprites not yet placed right (decospr flip / 256-vs-320 count). Next.

Commit: "osman: gate 8x8/16x16 tilemap by control1[7] (deco16_pf_update enable)"

## 'BEST 10' text sprites missing — decospr scanned only 256 sprites (osman draws 320)

**Symptom:** the ranking text (BEST 10 / scores / 3RD) never appeared.

**Root cause:** simpl156 draw_sprites uses 0x1400/4 = 320 sprites; jtframe_decospr hard-scanned
256 (`oram_addr[9:2]==8'd255`). The text characters live in slots 256-319 -> never scanned.

**Fix:** parametrize the scan — SPRW (sprite-index bits), LASTSPR (last index), LINEMAX (per-line
budget); default 8/255/58 keeps cninja bit-identical. Osman uses SPRW=9, LASTSPR=319, oram_addr
widened to [10:0]. Text now renders and the BEST-10 scene matches MAME.

Commit: "osman: scan 320 sprites (decospr SPRW/LASTSPR param) — BEST 10 text renders"

## Sprite priority (pri_callback) — sprites split above/below the front playfield

simpl156 draws pf2 at priority 2, pf1 at priority 4; pri_callback maps sprite pri
(word2[15:14]) to a pmask so pri 0/1 sprites draw in FRONT of pf1 and pri 2/3 sprites
are occluded by pf1 (drawn between pf1 and pf2); pf2 never occludes sprites. Wire it in
jtosman_colmix: obj_pxl[10] (pri[1]) splits front vs mid. Priority order:
obj(pri0/1) > pf1 > obj(pri2/3) > pf2 > backdrop. Scenes use pri 3 heavily (dragon boss).

Commit: "osman: wire sprite priority (pri_callback) — pri 2/3 sprites between pf1 and pf2"
