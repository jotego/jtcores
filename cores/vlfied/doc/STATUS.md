# Volfied (core `vlfied`) — STATUS

Driver mirrored at `doc/volfied.cpp`. Device sources it includes (`pc090oj`,
`taitocchip`, `taitosnd`) are in `cores/rastan/doc/`.

Boots to the full title screen at 60.10 Hz. The attract idle loop sits at
`A=005ce0..005cfa` — normal, not a hang.

## Sim

```bash
FRAMES=350 ROMS_HOST=~/mameroms ./sim-core.sh vlfied volfied
```

- Core `vlfied` ≠ setname `volfied`. ROMs are in `~/mameroms`, not `~/.mame/roms`.
- `doc/mame.xml` is **repo-global**, not per-core. A full `jtframe mra --reduce`
  drops all ~57 CPS3 sets here (`cores/cps3` is an uninitialized private
  submodule) — insert new machines surgically instead of overwriting.
- Run `jtframe` in `jotego/simulator:arm64`; `sim-core.sh` leaves an aarch64
  binary the amd64 image can't exec (symptom: empty output, no error).

## Refactor: reuse rastan's chips

Volfied ≈ Rastan minus the tilemap and the YM2151/ADPCM pair, plus a C-chip and a
bitmap framebuffer. Shared chips come from a `rastan:` section in `cfg/files.yaml`
(cross-core pull — 80+ cores already do this).

| Function | Volfied | Rastan | Status |
|---|---|---|---|
| Main↔sound | PC060HA | PC060HA | ✅ step 1 — uses `jtrastan_pc060.v` |
| Protection | TC0030CMD @ 10 MHz | opwolf/rbisland | ✅ step 2 — uses `modules/jttc0030cmd` |
| Sprites | PC090OJ | PC090OJ | ✅ step 3 — uses `jtrastan_obj.v` verbatim |
| Raster | 320×256, visarea 0–319 / 8–247, 60 Hz | **identical** | ⬜ step 4 — lift rastan's vtimer |
| Sound chip | YM2203 (`jt03`) | YM2151 + MSM5205 | nothing to share |
| Background | bitmap framebuffer | PC080SN tilemap | no donor — `jtvlfied_fb.v` |

### Step 1 (done) — PC060HA

`jtvlfied_pc060.v` deleted. `jtvlfied_main` now exposes `cpu_cen` (8 MHz,
`num=1/den=6`); `jtvlfied_snd` derives `snd_cen = main_cen & snd_cen_tog` (4 MHz)
feeding **both** the Z80 and the PC060HA sound side — they must share a cen, the
handshake edge detection samples on it. YM2203 stays on the free-running `cen4`
(mirrors rastan keeping its OPM on `fm_cen`). The old `clk48`/`clk24` split was
vestigial: both were tied to the same `clk` at the top level.

### Step 2 (done) — C-chip

`jtsuperman_cchip.v` + `jtsuperman_upd78c11.v` and the four baked `.mem` files
deleted (16,785 lines); `jtvlfied_cchip.v` is now a thin port-mapper over
`modules/jttc0030cmd`. `int1` is just `~LVBL` — the module conditions the edge
internally, no pulse shaper needed. The `REAL_MCU` stub branch and the dead
`cchip_dtackn` path are gone.

ROM download replaces `$readmemh`: `bram:` entries `cchip_mask` (AW 12) /
`cchip_eprom` (AW 13) both `prom: true`, `cchip_cen` at 10 MHz, plus
`zip.alt="cchip.zip"` and the `cchip_bios` / `cchip:cchip_eprom` regions in
`mame2mra.toml`. **`JTFRAME_PROM_START=0x200000`** — required, and it sits at
`BA3_START` because bank 3 is a RAM-only framebuffer that downloads nothing.

**`~/mameroms/cchip.zip` was reconstructed locally** from the old `mask_rom.mem`
(crc `43021521`, verified) — it is not in any romset here, and the sim needs it.

Verified: 19 of 20 frame CRCs pixel-identical to the pre-swap run, and both PROMs
land in `rom.bin` at `PROM_START` with matching CRCs.

### Step 3 (done) — PC090OJ

`jtvlfied_obj.v` deleted, `jtrastan_obj.v` adopted **verbatim** — the rastan module
is untouched, so opwolf/rbisland cannot regress. Port lists were already identical;
only `main_addr[10:1]` → `[12:1]` (rastan's own width, and wider than the fork's).

Three of the four fork differences dissolved: the wider RAM is strictly better, the
cocktail mirror is identity when the flip DIP is off, and the sprite-code fold moved
to the MRA where it belongs — MAME `ROM_RELOAD`s c04-10/c04-09 at 0xa0000 and
mame2mra does not replicate `ROM_RELOAD`, so `rom.bin` was FF-padded there.
`sequence=[0,1,2,3,4,5,4,5]` on the pc090oj region repeats those two files, making
the region a faithful 768 KB (verified: `rom[0xa0000:0xc0000] == rom[0x80000:0xa0000]`).

**Open: sprites sit 9 lines high.** Measured against the pre-swap frame the image is
a 100.0% pixel match at `dx=0, dy=-9` — a pure uniform translation, nothing else
changed. That is rastan's `buf_pos = xpos + 13` vs the fork's `+4`. Deliberately NOT
compensated: resolve it in the step-4 vtimer work rather than with a magic constant.
On ROT270 the sprite raster-H axis is display-vertical, which the `dx=0` confirms.

## Known gaps

- Video timing still placeholder (`JTFRAME_PXLCLK=8`); step 4 lifts rastan's, and
  should be judged against the 9-line sprite offset above.
- `ifdef SIMULATION` debug counters in `jtvlfied_main.v` / `_colmix.v` / `_fb.v`
  to strip before release.
