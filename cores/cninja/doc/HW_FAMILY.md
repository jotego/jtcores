# Caveman Ninja Hardware — multi-game plan (header-driven, one bitstream)

Per system16.com (id=944) this PCB ("Data East Caveman Ninja Hardware") runs 7
game families. We support them in ONE bitstream selected by an MRA header byte
(the superman/kiwi pattern), NOT separate forks.

Shared spine (all 7): 68000@12MHz, HuC6280, 2x deco16ic, 1x decospr,
YM2203 + YM2151 + 2x OKIM6295, 256x240 (robocop2/mutantf are 320 — later phase).

## Header config

`JTFRAME_HEADER=16`. Byte 0 = `game_id[3:0]`. The HDL decodes game_id once at
download (mirror of jtsuperman_game.v `prog_we && header && prog_addr[3:0]==0`)
and muxes: address-decode variant, protection path, and the HuC6280 / YM2203
clock cens. `game_id=0` == today's cninja behaviour (no regression).

| id | game(s)                         | tilegens @    | I/O @            | prot   | HuC6280   | YM2203  | screen |
|----|---------------------------------|---------------|------------------|--------|-----------|---------|--------|
| 0  | cninja / joemac                 | 14xxxx/15xxxx | 17ff2x (via 104) | DECO104| 32.22/8   | 32.22/8 | 256    |
| 1  | cbuster / twocrude              | 0a0xxx/0a8xxx | 0bc00x (direct)  | none   | 24/4=6M   | ~1.34M* | 256    |
| 2  | darkseal / gatedoom             | 200xxx/260xxx | 18000x (direct)  | none   | 32.22/4   | 32.22/8 | 256    |
| 3  | edrandy                         | (146 map)     | via 146          | DECO146| 32.22/8   | 32.22/8 | 256    |
| 4  | mutantf / deathbrd              | (146 map)     | via 146          | DECO146| 32.22/8   | none    | 320 †  |
| 5  | robocop2                        | (146 map)     | via 146          | DECO146| 32.22/8   | 32.22/8 | 320 †  |
| 6  | vaportra / kuhga                | (mxc06 sprite)| direct           | none   | 32.22/4   | 32.22/8 | 256 ‡  |

\* cbuster YM2203 = 32.22/24*3 = 1.3425 MHz ("YM2203_PITCH_HACK" in MAME).
† 320-wide + DECO146 → Phase 3 (needs the 146 + a 320 video variant).
‡ vaportra swaps decospr for the older deco_mxc06 sprite chip → Phase 4.

## Easiest order (no-protection first)

1. **cbuster / twocrude** (id 1) — no protection, direct I/O at 0x0bc00x, but
   HuC6280=6MHz and YM2203=1.34MHz (clock-cen mux) + its own ROM map.
2. **darkseal / gatedoom** (id 2) — no protection, direct I/O at 0x18000x,
   HuC6280=8.06MHz, YM2203 same as cninja. Own ROM map.
3. **edrandy** (id 3) — needs DECO 146 (we have deco146.cpp in doc/).
4. robocop2 / mutantf — DECO146 + 320 video. vaportra — mxc06 sprite.

## Per-game bring-up checklist (cbuster first)

- [ ] Mirror cbuster.cpp/.h into doc/ (fetched to /tmp; copy in).
- [ ] mem.yaml: union of bank layouts; cbuster ROM regions + offsets.
- [ ] mame2mra.toml: [header] block (cninja=00, cbuster=01...), cbuster region map.
- [ ] _main.v: game_id-muxed address decoder + direct-I/O (P1_P2/DSW/COINS @ 0bc00x).
- [ ] game.v: latch game_id; mux cen_opn/cen_snd by game_id.
- [ ] Boot trace cbuster (MAME) vs FPGA PC dumper.
- [ ] Scene replay + scenesim diff vs MAME.

## NEEDED FROM USER

- `cbuster.zip` (+ parent for clones: cbusterw/cbusterj/twocrude)
- `darkseal.zip` (+ darksealj/gatedoom/gatedoom1)
- standard MAME 0.276 split sets.
