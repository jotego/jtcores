# Money Money schematic set — sheet index

Source: `money_money.pdf` (Zaccaria technical manual, 17.5.1983, codice gruppo CEC 278)

| PDF page | Board | Code | Sheet | Content |
|---|---|---|---|---|
| 1 | — | — | — | Cover |
| 2 | — | — | — | DIP switch tables (SW 5I, SW 4I, SW 3I) |
| 3 | Video | 1B11140 (CEC 275) | 1/5 | Clock gen, H/V counters, sync/blank, flip XORs, palette PROMs + RGB DAC |
| 4 | Video | 1B11140 | 2/5 | Background: scroll adders, tile RAM (2114), bg ROMs 4A/4C/4E, LS194 shifters, CN2 |
| 5 | Video | 1B11140 | 3/5 | Objects: line buffers 2148H, H position counters, 82S100 PLAs 8C/8N |
| 6 | Video | 1B11140 | 4/5 | CONTROL LOGIC 1 (6J) / 2 (6K) customs, object RAM 1L/1M (2114), collision |
| 7 | Video | 1B11140 | 5/5 | CN1 pinout, LS153 9C mux, BK latch 9B, VIDOUT flop |
| 8 | I/O (CPU) | 1B11141 (CEC 274) | 1/3 | Z80, ROM 1A/1B, RAM 2A/2B + NVRAM 2C/2D, decode, LS259 3G, watchdog, battery |
| 9 | I/O (CPU) | 1B11141 | 2/3 | 8255, controls, DIP diode matrix + 40097 muxes, sound latch 2H, coin counter |
| 10 | I/O (CPU) | 1B11141 | 3/3 | CN1 / CN3 pinouts |
| 11 | Audio | 1B11142 (CEC 276) | 1/3 | Melody 6802 4L, 3.580MHz, 4040 divider, PIA 4I, 2× AY-3-8910 (4H, 4G) |
| 12 | Audio | 1B11142 | 2/3 | Analog filters (rullante/cassa/basso/piano/tromba), LS156 4B ladder, TDA1510 amp |
| 13 | Audio | 1B11142 | 3/3 | Speech/effects 6802, PIA 1I, SPEECH 1H (TMS5200), MC1408 DAC, HS latch |
| 14 | ROM module | 1B11147 (CEC 277) | 1/2 | Main CPU ROMs 2/3/4/10/11, protection PAL (pos 1), bg ROM option B1/B2/B3 |
| 15 | ROM module | 1B11147 | 2/2 | Audio-board ROMs 7/8 (melody CPU) and 9/13 (speech CPU) via CN3 |

Digests: `1b11140-video.md`, `1b11141-io.md`, `1b11142-audio.md`, `1b11147-rom-module.md`.

Signal naming: trailing `*` or overbar in the schematic = active low (written here with a
leading `/`). `nH`/`nV` are horizontal/vertical counter bits (n = weight). Primed
signals (e.g. `128V'`) are the flip-XORed versions.
