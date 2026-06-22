# 005885 implementation for Double Dribble — design notes

This document explains how we implement the Konami 005885 custom graphics generator for our jtcores Double Dribble port. Living document — updated as we add phases.

## Canonical lint command (DO NOT FORGET ACROSS COMPACTION)

Run this from the repo root (`/Users/andreabogazzi/develop/jtcores`). It is the **only** lint invocation that works on this machine — `lint-one.sh` is the script, the entrypoint of `jotego/simulator` is `bash` (so `-c` works directly), and `setprj.sh` lives under `modules/jtframe/bin/`, not the repo root. `unset VERILATOR_ROOT` is required both before and after sourcing setprj.

```bash
docker run --platform linux/amd64 --rm \
  -v "$(pwd):/jtcores" -w /jtcores \
  jotego/simulator -c "
    mkdir -p .git/hooks 2>/dev/null
    unset VERILATOR_ROOT
    source modules/jtframe/bin/setprj.sh --quiet >/dev/null 2>&1
    unset VERILATOR_ROOT
    lint-one.sh ddribble 2>&1 | tail -40
"
```

Expected clean output ends with `====== JTSIM finished in N's ======`. Pre-existing PINMISSING warnings on `jt03` (IOA_oe, IOB_oe, psg_A/B/C, debug_view) are baseline — those output pins are deliberately unconnected in `jtddribble_sound.v`.

## Strategy

The 005885 is a Konami proprietary tile-and-sprite generator (1986). No public datasheet exists; the closest things to authoritative documentation are:

1. **The PCB schematic** (page 0 of our packet) — shows the **external pin labels** of the chip at designators E16 and H16. Tells us how the chip is connected to the rest of the board.
2. **MAME `konami/ddribble.cpp`** — driver-level emulation. The 005885 behaviour is **inlined inside `ddribble_state` class** (no standalone `k005885.cpp`). Functions to study: `k005885_w<>` (register writes), `fg_videoram_w` / `bg_videoram_w` (VRAM writes), and the tilemap+sprite render routines.
3. **MiSTer Iron Horse `rtl/custom/k005885.sv`** — an MIT-licensed SystemVerilog model by Ace (2020-2022). Functionally complete but written for the MiSTer framework (Altera RAM primitives, internal VRAM, expects 49.152 MHz clock). Kept here as `k005885_REFERENCE.sv` — READ-ONLY, NOT in the build.

### Why we write our own instead of pulling in the MiSTer file

Four real-world integration mismatches make drop-in impractical (detailed in the chat that produced this doc):

| Mismatch | MiSTer k005885.sv | Our jtcores setup |
|---|---|---|
| RAM primitives | `spram` / `dpram_dc` (Altera VHDL) | `jtframe_ram` / `jtframe_dual_ram` (Verilog, framework-standard) |
| VRAM storage | Internal to the module | External BRAMs declared in our `mem.yaml` |
| Clock domain | Needs 49.152 MHz on `CK49` | We use clk24 + cen patterns from `mem.yaml` |
| CPU clock generation | Module produces 6809 E/Q internally | Our 3 CPUs are driven by `cpu_cen` from mem.yaml |

JTFRAME's idiom is to write custom modules that fit the framework — `jtkicker` does exactly this for Konami 082/083/502/503 chips. We follow the same pattern for 005885.

### License of the new module

`jtddribble_5885.v` (the one we WRITE) ships under jtcores' **GPL-3**. If we copy any substantial code chunks from `k005885_REFERENCE.sv` (Ace's MIT work) into it, we include the MIT notice in the relevant section of our file's header. Behavioural inspiration alone (reading the file to understand the chip) doesn't trigger any copyright concern.

## Build phases

| Phase | Subject | Status |
|---|---|---|
| 0 | Port list — interface grounded in schematic pin labels | ✅ done |
| 1 | Module shell with stubbed outputs (compiles, does nothing useful) | ☐ next |
| 2 | CPU register decoder (writes to A[13:0] register window) | ☐ |
| 3 | Internal 8 KB SRAM (the on-chip equivalent of the 6264SL) + VRAM tile-code access | ☐ |
| 4 | Tile pixel pipeline: read tile codes from internal SRAM, fetch graphics from gfx1/gfx2 SDRAM, output VCD/VCB color bus | ☐ |
| 5 | Sprite engine: parse sprite list from internal SRAM, fetch sprite graphics, line-buffer composition, output BCD/BCB color bus | ☐ |
| 6 | Internal sync generator (the 005885 OWNS the video-clock domain) | ☐ |
| 7 | Integration in `jtddribble_video.v` — 2 instances (one per layer), priority mux (LS157 H13/H14) + 007327 palette lookup. **At this phase Option A wiring is done**: `u_5885_1.NCPE` drives main CPU `cen` | ☐ |

## Design contracts (locked decisions)

1. **CPU clocks come from the 005885 (Option A).** `NCPE` (pin 104) and `NCPQ` (pin 55) outputs of the FIRST 005885 instance will drive the main CPU's `cen` input. Wiring deferred to Phase 7 integration; until then `cpu_cen` from `mem.yaml` is used (functionally equivalent rate, just decoupled).
2. **The 6264SL VRAM and 4464 sprite framebuffer are INTERNAL to the 005885 module.** Modelled via `jtframe_ram` instances inside `jtddribble_5885.v`. The CPU reaches them through the chip's CPU-bus interface (`A`, `DB`, `NXCS`, `NRD`). No external BRAM ports for these.
3. **Two instances of `jtddribble_5885`** — one per layer (chip #1 = E16, chip #2 = H16). Same module instantiated twice.
4. **External wiring**: only CPU bus + ROM bus + clocks + sync + color out + interrupts. ~50 ports total.

## Phase 0 outcome — port list (grounded in user's pin-trace + Furrtek-style cross-check)

```
// Clock domain  ----------------------------------------------------------
input            CK18           ;   // pin 1     master 18.432 MHz from page-0 osc-can
output           NCPE           ;   // pin 104   E clock to main CPU (Option A locked-in)
output           NCPQ           ;   // pin 55    Q clock to main CPU
output           NEQ            ;   // pin 56    E·Q AND — feeds 007552 PAL G2B
output           NCK2           ;   // pin 3     buffered clock distribution
// disconnected on this PCB: NCK1 (pin 2), 1H6 (pin 58)

// CPU bus  ---------------------------------------------------------------
input  [13:0]    A              ;   // pins 50,49,98,48,97,138,47,96,137,46,95,136,45,94
inout  [ 7:0]    DB             ;   // pins 52,101,142,51,100,141,99,139 (= CD0..CD7 bus)
input            NXCS           ;   // pin 54    chip select from main-CPU address decoder
input            NRD            ;   // pin 102   (= CRTRD net)
input            NREG           ;   // pin 44
input            NEXR           ;   // pin 43    external reset

// CPU interrupt outputs  -------------------------------------------------
output           NIRQ           ;   // pin 41
output           NNMI           ;   // pin 42
output           NFIR           ;   // pin 92

// Tile/sprite graphics ROM bus (to external MASK1Ms)  --------------------
output [15:0]    R              ;   // pins 8,63,7,62,109,148,6,61,108,147,5,60,107,146,110,149
input  [ 7:0]    RDU            ;   // pins 10,65,112,151,9,64,111,150
input  [ 7:0]    RDL            ;   // pins 68,12,67,114,11,66,113,152

// Sync outputs  ----------------------------------------------------------
output           NCSY           ;   // pin 4     composite sync
output           NYSY           ;   // pin 59    vertical sync (likely "NVSY" typo on schematic)

// Color outputs  ---------------------------------------------------------
output [ 4:0]    COL            ;   // pins 14,13,16,17,70  final 5-bit color
output [ 3:0]    VCB,VCD        ;   // VRAM color bus (tile path)
output [ 3:0]    BCB,BCD,BCF    ;   // Sprite color bus
// VCF (pins 23,76,121,158) — grounded externally — likely a config-mode input;
// NOT a Verilog port (tie internally to 4'b0 or treat as parameter)

// PCB-only pins, NOT module ports  ---------------------------------------
// VCC:        159,173,169,161,157,153,145
// GND:        57,69,81,93,105,115,120,125,135,140
// TES1-TES9:  130,165,168,170,171,172,174,175,176  — grounded test pins
// Disabled/grounded: NBUE (106); disconnected: NIBC (144), NRMW (53), NWCS (103), N5D1 (143)
// FA/FD/NRAS/NCAS/NFOE/NWR0/NWR1: external 4464 framebuffer interface —
//   IN OUR HDL the framebuffer lives inside the module as jtframe_ram (no external ports)
// VO/AX/NVOW/NROE/NVOC: 6264SL VRAM interface — same, INTERNAL jtframe_ram
```

About 50 ports total. Ready for Phase 1.

## MAME references collected so far (will grow)

| File / lines | Subject |
|---|---|
| `konami/ddribble.cpp:~70-100` | `k005885_w<>` template — CPU writes to 005885 registers (0x0000-0x0004 for #1, 0x0800-0x0804 for #2) |
| `konami/ddribble.cpp:fg_videoram_w` | FG VRAM write handler — main CPU writing tile codes |
| `konami/ddribble.cpp:bg_videoram_w` | BG VRAM write handler — same for BG |
| `konami/ddribble.cpp:get_fg_tile_info` | Tile info packing for FG layer |
| `konami/ddribble.cpp:get_bg_tile_info` | Same for BG |

(Will fetch exact line numbers as we hit each phase.)

## Schematic references collected so far (will grow)

| Page / tile | Subject |
|---|---|
| Page 0 around designator E16 | 005885 #1 (FG layer). Pins labelled VCB7..0, VCD7..0, MRNW, NCS, MIBC, N1BC, NIRQ, NMI, NMRO, NRES, NEXR, NFIR, NFL12, NFLIP2, R/B0..7, RDU0..7, RDL0..7, CKIS, NCK1, NCK2, NCFE, NCFG, NEQ, NBUE |
| Page 0 around designator H16 | 005885 #2 (BG layer). Same pin layout. |
| Page 0 LS157 at H13/H14 | Priority mux: G1COL[4:0] vs G2COL[4:0] gated by PRI → COL[4:0] |
| Page 0 designator I1 | 007327 palette LUT — takes COL[4:0] + lookup PROM at I15 → RGB to JAMMA edge |

## Open questions

(Will grow as we work through phases.)

- Phase 0: do the pin names on E16 and H16 match exactly, or does the BG instance (H16) have different labels reflecting its different role?
- Phase 6: does the 005885's internal NCSY/NVSY drive the board's sync, or is the page-0 sync chain (LS393 I9 + LS161 D14 + LS74) generating sync independently and the 005885 just receiving sync as input?


PINS list: we have 2 5885 chips, if it says grounded or 5v or else it means valid for both chips
VCC (159,173,169,161,157,153,145) 5v
GND (57, 69,81,93,105,115,120,125,135,140) grounded
NT1H (29)
TES1 - TES9 (130,165,168,170,171,172,174,175,176,57) grounded
CK18 (1)
NCK1 (2) disconnected
NCK2 (3)
1H6 (58) disconnected
NCPE (104)
NCPQ (55)
NEQ (56)
NBUE (106) grounded
NFIR (92)
NIRQ (41)
NNMI (42)
NRD (102) connected to CRTRD
NREG (44)
NEXR (43)
NXCS (54)
NIBC (144) disconnected
NRMW (53) disconnected
NWCS (103) disconnected
N5D1 (143) disconnected
A0-A13 (50,49,98,48,97,138,47,96,137,45,95,136,45,94)
DB0-DB7 (52,101,142,51,100,141,99,139) connected bus CD0-CD7
// strange network start ( 05585 own memory to 2 4464 chips )
NRAS (30) to 4464 RAS
NCAS (28) to 4464 CAS
NFOE (82) to 4464 OE
NWR1 (80) to 4464 WR for FD0-FD3
NWR0 (27) to 4464 WR for FD4-FD7
FA0 - FA7 (24,77,122,25,123,160,79,124) to 4464 A0-A7
FD0 - FD7 (31,32,83,126,33,84,127,162) to different 4464 0-3 and 4-7
// strane network end
NT1H (29) grounded
TES1-TES9 (130,165,168,170,171,172,174,175,176) grounded
// another strange network with a single 6264sl involved (objects? sprites?)
VO0-VO7 (34,85,128,163,35,86,129,164) going to 6264SL D0-D7
AX0-AX12 (36,87,37,88,131,166,38,89,132,167,39,90,133) going to 2624DL A0-A12
NVOW (40) goes to 6264SL R/W
NROE (91) goes to 6264SL OE
NVOC (134) disconnected
// another strange network end
NYSY (59)
NCSY (4)
COL0-COL4 (14,13,16,17,70)
BCD0-BCD3 (15,18,19,72)
BCB0-BCB3 (71,116,117,154)
BCF0-BCF3 (20,73,118,155)
VCD0-VCD3 (22,75,78,26)
VCB0-VCB3 (21,74,119,156)
VCF0-VCF3 (23,76,121,158) grounded
RDL0-RDL7 (68,12,67,114,11,66,113,152) comes from roms MASK1M
RDU0-RDU7 (10,65,112,151,9,64,111,150) comes from roms MASK1M
R0-R15 (8,63,7,62,109,148,6,61,108,147,5,60,107,146,110,149) address roms MASK1M bu addressing differs between chips and there is more stuff going on with mask1m chips. 1 chip address 2 mask1m roms, the other 6.
---

## References — Konami 007121 (the cousin chip, decapped by Furrtek)

Source: <https://github.com/furrtek/SiliconRE/tree/master/Konami/007121>
- `007121_schematics.pdf` — full die-traced schematic
- `007121_trace.svg` — die-level routing
- `007121_pinout.ods` — pinout spreadsheet
- `README.md` — register documentation, sprite format, interrupt behaviour

The 005885 (1986) and 007121 (1987-88) are likely architectural siblings — both Konami tile/sprite controllers, same generation of MC6809-based boards. **No silicon decap exists for 005885 itself**, so 007121's documented internals are the closest authoritative reference we have besides MAME and MiSTer.

### Architectural patterns we expect to find in 005885 too (cross-checked against MAME + schematic)

| Pattern | 007121 says | Confirms / informs in 005885 |
|---|---|---|
| **Interrupt model** | Chip generates NMI (every 32/64 lines), IRQ (at VBLANK), FIRQ (toggles on IRQ-clear). Reg 7 enables/clears. | MAME ddribble.cpp shows main+sub CPUs get FIRQ on VBLANK. Matches. Our HDL Phase 6 should mirror: register-controlled enable/clear, FIRQ on VBLANK edge. |
| **Sprite line buffer** | External DRAM, written/read 2 pixels at a time (8 bits = 2 × 4bpp) | Our schematic shows 2× 4464 DRAMs with NRAS/NCAS/FA/FD per 005885 instance. Identical pattern. Confirms DRAM-as-internal-framebuffer model. |
| **Graphics ROM bus** | 16-bit data (4 × 4bpp pixels per fetch), dynamic address composition from tile codes + counters + flip bits | Our schematic confirms RDU+RDL = 16 bits per fetch, R[15:0] address. Same. |
| **CPU writes to palette via chip pins** | When NWCS low, CPU's A[1:7] routed to COA pins → CPU writes palette through the chip | Need to verify if 005885 has same mechanism. Our schematic shows palette RAM is inside 007327 chip; relationship to 005885 needs trace. |

### Architectural patterns that DIFFER (005885 simpler than 007121)

| | 007121 | 005885 (per MAME + schematic) |
|---|---|---|
| Register count | 8 (Reg 0-7) | 5 (MAME's k005885_w handles offsets 0-4) |
| Color bus width | 7 bits (COA[6:0]) — pixel + sprite/scroll bit + 2 software-set extras | 5 bits (COL[4:0]) — just pixel + 1 extra |
| Layers per chip | 1 (scroll + sprites, two layers need two chips in some games) | 1 (we use 2 chips: E16 + H16 for FG + BG) |
| Scroll RAM | 288 latches (32 × 9-bit) for per-row or per-column scrolling | Probably absent — Double Dribble doesn't need per-row scrolling. Single X+Y per layer. |
| Sprite sizes | 5 modes: 8×8, 8×16, 16×8, 16×16, 32×32 | Unknown — likely a subset. MAME render code will reveal. Assume 16×16 (Konami standard) as starting point. |

### 007121 register summary (use as sanity check when interpreting MAME's k005885_w)

```
Reg 0: X scroll, lower 8 bits
Reg 1: bit 7 = NRM control, bit 3 = text mode, bit 2 = row/col scroll select,
       bit 1 = enable row/col scroll, bit 0 = X scroll MSB
Reg 2: Y scroll value
Reg 3: bit 6 = blanking, bit 5 = priority mode, bit 4 = text mode (limits sprite area),
       bit 3 = sprite-table select, bit 2 = priority (opaque sprite topmost),
       bit 0 = gfx ROM A13 for scroll tiles
Reg 4: per-bit override for tile code bits 12:9 (0=from VRAM attr, 1=from this reg)
Reg 5: maps VRAM attribute bits → tile code bits 12:9
Reg 6: bit 5 = COA6, bit 4 = COA5, bit 3 = enable attr bit 6 as priority flag,
       bit 2 = enable attr bit 5 as Y flip, bit 1 = enable attr bit 4 as X flip,
       bit 0 = enable attr bit 3 as VCB3
Reg 7: INTERRUPT CONTROL — bit 4 = NMI rate (32 vs 64 lines), bit 3 = flip XY,
       bit 2 = FIRQ enable/clear, bit 1 = IRQ enable/clear, bit 0 = NMI enable/clear
```

When we read MAME's 5-register `k005885_w<>`, expect to find:
- Scroll registers (X, Y) — probably 2 registers
- Mode/control register — probably 1
- Interrupt-control register — probably 1
- Bank/flip register — probably 1

Map 007121's 8 registers onto 005885's 5 by combining/dropping the features that aren't needed in 1986-era games.

### 007121 sprite list format (5 bytes per sprite — adopt as starting hypothesis for 005885)

```
Byte 0: tile code bits 7:0   (bits 1:0 may be replaced by counter for 32×32)
Byte 1: bit 7:4 = palette
        bit 3:2 = tile code low bits (used for non-32×32)
        bit 1:0 = sprite ROM bank low bits
Byte 2: Y position
Byte 3: bit 7:1 = X position high bits
        bit 0   = odd/even pixel select for line buffer write
Byte 4: bit 7:6 = sprite ROM bank high bits
        bit 5   = Y flip
        bit 4   = X flip
        bit 3:1 = sprite size (8×8 / 8×16 / 16×8 / 16×16 / 32×32)
        bit 0   = X position MSB
```

Verify against MAME ddribble.cpp's sprite render functions before committing to this layout.

### When to consult 007121 during 005885 implementation

- **Phase 2 (register decoder)**: use 007121 register map as starting template; verify each bit against MAME's `k005885_w<>` semantics
- **Phase 3 (internal SRAM)**: confirms tilemap is split into code-attribute pairs per tile
- **Phase 4 (tile pipeline)**: 007121 GFX ROM address composition table is reference for how counters + flip bits + code bits combine
- **Phase 5 (sprites)**: sprite list format as hypothesis to verify against MAME render code
- **Phase 6 (sync + interrupts)**: interrupt enable/clear model directly applicable

### Source citation discipline for the HDL

When we write 005885 internal logic, the comment above each block cites the SOURCE:

```verilog
// Tile-code high bits assembled per Reg 4/5 mux logic.
// SOURCE: MAME k005885_w<>:NNN + cross-checked against
//         007121 register doc (Reg 4-5 family pattern, same idea simplified).
```

If MAME and 007121 disagree, MAME wins (it's specific to OUR chip). If MAME is ambiguous, 007121 disambiguates. If both are silent, MiSTer reference fills the gap.

---

## References — MAME k007121.cpp vs 005885 (inline in ddribble.cpp)

Source files compared:
- `src/mame/konami/k007121.cpp` (469 lines, standalone device file, license BSD-3-Clause, copyright Fabio Priuli + Acho A. Tang + R. Belmont)
- `src/mame/konami/ddribble.cpp` (005885 logic inlined in `ddribble_state` class)

### The smoking-gun confirmation

MAME's `k007121.cpp` header opens with:

> **"This is an interesting beast. It is an evolution of the 005885, with more features. Many games use two of these in pair."**

This is DOCUMENTED CONFIRMATION (from MAME's own developers) that 007121 directly evolves 005885. Whatever 007121 does, 005885 does a SUBSET of (with maybe slightly different bit layouts).

### External-interface comparison

| Pin/bus | 005885 (our schematic + ddribble.cpp) | 007121 (Furrtek decap + k007121.cpp) |
|---|---|---|
| CPU address | A[13:0] | A[13:0] (same) |
| CPU data | DB[7:0] | DB[7:0] (same) |
| Tilemap RAM bus | AX[12:0], VO[7:0] (drives 6264SL externally) | AX[12:0], VO[7:0] (drives 8 KB ext SRAM — same) |
| Sprite framebuffer DRAM | NRAS/NCAS, FA[7:0], FD[7:0], NWR0, NWR1, NFOE (2× 4464) | Same exact pinout (2× 64Kx4 DRAMs) |
| Tile/sprite ROM bus | R[15:0], RDU+RDL = 16-bit data | R[17:0] — **18 bits**, RDU+RDL = 16-bit data |
| Tile lookup PROM | VCD/VCB/VCF | VCD/VCB/VCF (same) |
| Sprite lookup PROM | BCD/BCB/BCF | OCB/OCF (different naming, same concept) |
| Final color | COL[4:0] — **5 bits** (4bpp pixel + 1 sprite/tile bit) | COA[6:0] — **7 bits** (4bpp pixel + 1 sprite/tile + 2 software-set extras) |
| CPU clocks generated | NCPE, NCPQ | NE, NQ (same role) |
| Interrupts to CPU | NIRQ, NNMI, NFIR (all 3) | NNMI, NIRQ, NFIR (same) |
| Sync output | NCSY, NYSY | (similar — produces sync) |

The 005885 ROM bus has **fewer address bits** (16 vs 18) → max 64 KB × 16 bits = 128 KB of graphics per chip. The 007121 supports up to 512 KB. Our schematic confirms chip #2 wires 4 × 128 KB MASK1M = 512 KB total (matches MAME `gfx2`), achieved by external bank gating of R16/R17 — visible on our page-0 schematic as the LS00 at C10 with R16/R17/R17N nets.

### Register-write handler comparison

**005885** (`ddribble_state::k005885_w`, lines 126-142 of `ddribble.cpp`):

```cpp
void ddribble_state::k005885_w(offs_t offset, uint8_t data)
{
    switch (offset)
    {
        case 0x03:  // char bank selection
            m_charbank[Which] = data & 0x03;  // 2 bits
            ...
            break;
        case 0x04:  // IRQ control, flipscreen
            m_int_enable[Which] = data & 0x02;  // bit 1 = enable
            break;
    }
    m_vregs[Which][offset] = data;  // store all writes for tilemap render to consult
}
```

**Only 2 of the 5 register offsets have behaviour in MAME**. Registers 0, 1, 2 are stored but not acted on in the switch — they're read later by the tile-render code (probably scroll X/Y or similar, but MAME's ddribble doesn't use them, presumably because Double Dribble doesn't scroll).

**007121** (`k007121_device::ctrl_w`, lines 204+ of `k007121.cpp`):

8 registers (offsets 0-7), much richer:
- Per-register dirty-tracking (marks tilemap dirty on writes that change layout)
- Offset 7: full interrupt control — clears NMI/IRQ/FIRQ individually, flipscreen, NMI rate

### Tile fetch format — 005885 (from `get_fg_tile_info`)

```cpp
attr = videoram[tile_index];            // first 0x400 bytes = attribute
num  = videoram[tile_index + 0x400]     // second 0x400 bytes = code low 8 bits
     + ((attr & 0xC0) << 2)             // attr[7:6] → tile code bits 9:8
     + ((attr & 0x20) << 5)             // attr[5]   → tile code bit 10
     + ((charbank & 2) << 10);          // charbank[1] → tile code bit 11
flipyx = (attr & 0x30) >> 4;            // attr[5:4] = flip Y, flip X
```

So 005885 VRAM layout (4 KB region):
- bytes 0x000-0x3FF = **attribute bytes** (1 per tile, 1024 tiles)
- bytes 0x400-0x7FF = **code low bytes**
- bytes 0x800-0xFFF = unused / mirrors? (tilemap is 64×32 = 2048 tiles, mapper skips 0x400)

Per `tilemap_scan`: address = `(col & 0x1F) + ((row & 0x1F) << 5) + ((col & 0x20) << 6)` — skips 0x400 boundary (because attr+code occupy paired 0x400 regions).

Tile code = 12 bits total (4096 unique tiles), composed of:
- 8 bits from code byte
- 2 bits from attr[7:6]
- 1 bit from attr[5]
- 1 bit from charbank reg

Attribute bit 5 is reused: contributes to tile-code bit 10 AND to flip-Y. That's intentional bit-layering Konami used for ROM-space economy.

**007121 equivalent**: documented as 13-bit tile code (one extra bit), with much more sophisticated mapping via Reg 4-5 (per-bit overrides of which attribute bit goes to which code bit). 005885 has the SIMPLE form of the same thing.

### What this tells us for our 005885 implementation

| Insight | Source | Implication for our HDL |
|---|---|---|
| Only 5 control registers, only 2 with real behaviour | MAME `k005885_w` | Phase 2 register decoder is SMALLER than I planned. ~10 lines of HDL. |
| Reg 3 = char bank (2 bits per chip) | MAME `k005885_w` case 0x03 | Bits 1:0 latched into a 2-bit reg per chip. Bit 0 may be unused; bit 1 = tile code bit 11. |
| Reg 4 = IRQ enable + flipscreen | MAME `k005885_w` case 0x04 | Bit 1 = interrupt enable. (NOT a per-IRQ control like 007121 Reg 7 — simpler!) |
| Registers 0, 1, 2 stored but inert in ddribble | MAME (stored in m_vregs[]) | They're scroll regs (X-lo, X-hi+mode, Y) — Double Dribble doesn't scroll, so MAME doesn't bother emulating their effect. Our HDL implements scroll anyway since the hardware does it (else iron-horse-style games on the same chip wouldn't work). |
| VRAM layout: 0x000-0x3FF attr, 0x400-0x7FF code, mapped via tilemap_scan | MAME tilemap_scan + get_fg_tile_info | Direct copy of layout into our jtframe_ram-backed 8 KB SRAM (lower 4 KB = tilemap, upper 4 KB = sprite list). |
| Tile code = 12 bits: 8 from code byte + attr[7:6] + attr[5] + charbank[1] | MAME `get_fg_tile_info` | Phase 4 tile fetch logic — exact algorithm. |
| FlipYX from attr[5:4] | Same | Direct bit-extract — trivial. |
| 007121 has 18-bit ROM addr; 005885 has 16-bit ROM addr | k007121.cpp header vs schematic | Bank-gating done externally on 005885 via R16/R17 + LS00 at C10. |
| 007121 has 7-bit color output, 005885 has 5-bit | Both files | Don't emulate 007121's COA5/COA6 — our chip outputs only COL[4:0]. |

### MAME-vs-MAME tie-breaker rule for ambiguous cases

When MAME's inlined 005885 logic in `ddribble.cpp` is ambiguous or skips a feature (because ddribble doesn't use it), we look at:

1. **MAME's `k007121.cpp` standalone device** — for the equivalent feature in the successor chip
2. Adapt that feature back to 005885 by ASSUMING 005885 uses a SUBSET / simpler version
3. Cross-check against the MiSTer reference (`k005885_REFERENCE.sv`)

This is how we'll handle scroll registers in Phase 4 — `ddribble.cpp` doesn't fully implement scroll for 005885 (the game doesn't need it), so we look at how `k007121.cpp` handles its scroll registers and back-port the simpler version.

### Bottom line for the implementation plan

- **Phase 2 just shrunk** — only 5 registers, only 2 active. ~10 lines of HDL.
- **Phase 3-4 plan unchanged** — internal 8 KB SRAM with tilemap layout per `tilemap_scan`.
- **Phase 5 sprite engine**: refer to `k007121.cpp`'s sprite render functions for the architectural pattern, then check `ddribble.cpp`'s `draw_sprites` for ddribble-specific bits.
- **Phase 6 interrupts**: 005885's IRQ enable is just one bit (Reg 4 bit 1). Much simpler than 007121's Reg 7. Just FIRQ on VBLANK gated by that bit.

---

## ⭐ MAJOR ASSET — `cores/contra/hdl/jtcontra_gfx.v` family (the 007121 HDL Jotego already wrote)

Source: `cores/contra/hdl/` — 3 files, GPL3, written by Jotego (Jose Tejada) in 2020:
- `jtcontra_gfx.v`           — 620 lines — top-level: register file, IRQ logic, tile/sprite mux, palette interface
- `jtcontra_gfx_tilemap.v`   — 205 lines — tilemap fetch + scroll
- `jtcontra_gfx_obj.v`       — 229 lines — sprite engine
- Total: ~1054 lines of GPL3 Verilog implementing the **007121** chip

### How it's used in the ecosystem

Pulled into other cores via `files.yaml` cross-core imports:

```yaml
contra:
  - get:
    - jtcontra_gfx.v
    - jtcontra_gfx_tilemap.v
    - jtcontra_gfx_obj.v
```

Six cores currently share this implementation: **contra, labrun (Labyrinth Runner), comsc (Combat School), flane (Fast Lane), castle (Haunted Castle), mx5k (MX5000)** — all 1987-88 Konami 6809 games using 007121.

### Why this changes our plan

The 007121 is documented (in `k007121.cpp`) as **"an evolution of the 005885, with more features"**. That means:
- **005885 ≈ jtcontra_gfx minus some features**
- Whatever jtcontra_gfx does, our 005885 does a SUBSET of
- Architecturally identical at the bus / interface / state-machine level

So our `jtddribble_5885.v` doesn't need to be invented from scratch. Three strategic options:

| Option | What | Pros | Cons |
|---|---|---|---|
| **A. Adapt jtcontra_gfx for 005885** (private copy) | Copy jtcontra_gfx.v + tilemap + obj into `cores/ddribble/hdl/jtddribble_5885.v` etc., strip features 005885 doesn't have (Reg 4-5 attr mapping, narrow_en, strip-scroll, etc.) | Fastest path to working pixels. Inherits Jotego's debugging effort. | Diverges from upstream contra; bug fixes don't propagate |
| **B. Reuse jtcontra_gfx via files.yaml + add a 5885 mode parameter** | Add `MODE_5885` parameter to jtcontra_gfx, get our core to pull it in via `contra: get:`. When MODE_5885=1, the module exposes only the 005885-subset behaviour | Shared code; bug fixes propagate everywhere. Cleanest long-term | Requires touching jtcontra_gfx.v which other 6 cores use; needs careful regression testing |
| **C. Reference jtcontra_gfx only, write our own** | Read jtcontra_gfx as template, write `jtddribble_5885.v` from scratch in JTFRAME style | Full control; no risk to other cores | Reinvents wheels; misses any subtleties Jotego solved |

### Recommendation

**Option A first (private adaptation), evaluate B later.**

Reasoning: getting working pixels on screen is the immediate goal. Option B is the right architectural answer eventually, but coordinating with the rest of jtcores would slow our learning. We start by copying + simplifying jtcontra_gfx into ddribble's hdl/. If after we have it working we want to upstream a unified 5885/7121 module, that's a separate PR.

### What to drop when adapting jtcontra_gfx for 005885

Based on our register comparison (005885 has 5 regs, only 2 with behaviour; 007121 has 8 regs with full feature set):

- **Drop Reg 4-5** (per-bit tile-code attribute mapping) — 005885 has hardcoded mapping (per `ddribble.cpp::get_fg_tile_info`: tile code = byte + attr[7:6] + attr[5] + charbank[1])
- **Drop Reg 6** (color attribute enables, COA5/COA6 outputs) — 005885 has 5-bit COL not 7-bit COA
- **Drop strip scroll** (mmr[1] bits) — 005885 doesn't support per-row/per-col scroll (Konami 1986 wasn't there yet)
- **Drop zure RAM** (32-entry latch array for row/col scroll) — same reason
- **Drop narrow_en + layout** (007121 screen-layout tricks) — 005885 is fixed 256×224
- **Simplify Reg 3** to just char_bank (2 bits) + flip (per MAME `k005885_w` case 0x03) — drop the rest of jtcontra's Reg 3 bits
- **Simplify Reg 7** to just `int_enable` (bit 1 per MAME `k005885_w` case 0x04) — 005885 doesn't have per-IRQ control like 007121 does
- **External R-bus is 16 bits** (not 18) — drop top 2 ROM-address bits; external R16/R17 banking gating done in our `_video.v` via the LS00 at C10 logic

### What to KEEP from jtcontra_gfx (the patterns that ARE schematic-faithful)

- **`mmr[0:N]` register file** pattern — clean, lints well
- **Tile fetch state machine** in `jtcontra_gfx_tilemap.v` — the timing of `vram_addr` / `vram_dout` / `R[15:0]` / `RDU` / `RDL` is exactly what 005885 does
- **Sprite fetch state machine** in `jtcontra_gfx_obj.v` — same
- **Line-buffer pattern** for sprite composition — direct reuse
- **IRQ/NMI/FIRQ generation timing** — same architecture, just simplified for 005885
- **External palette CS** (`col_cs`) — matches our 007327 wiring
- **JTFRAME idioms** — `rst`, `clk24`, `pxl_cen`, `pxl2_cen`, `LVBL`/`LHBL`/`HS`/`VS` ports

### Updated source-priority for the implementation

When we start Phase 2+, the source priority becomes:

1. **`cores/contra/hdl/jtcontra_gfx*.v`** — primary Verilog reference (Option A: copy + simplify)
2. **MAME `konami/ddribble.cpp::k005885_w` and `get_fg_tile_info`** — definitive answers for 005885-specific behaviour
3. **MAME `konami/k007121.cpp`** — for any feature jtcontra_gfx implements differently than Furrtek's decap
4. **Furrtek's 007121 docs** — for cross-checking semantics
5. **MiSTer `k005885_REFERENCE.sv`** — for any 005885 quirk only Ace knows about

### Bottom line

Phase 2 just got dramatically easier. We don't need to invent a register file — we copy Jotego's `mmr[0:7]` pattern and shrink it to `mmr[0:4]`. We don't need to invent a tile-fetch state machine — we adapt `jtcontra_gfx_tilemap.v`. We don't need to invent a sprite engine — we adapt `jtcontra_gfx_obj.v`.

Estimated implementation time: **3-4 focused sessions** instead of the original 7-phase multi-week plan.

---

## ⭐⭐ STRATEGY UPGRADE — parameterize, don't copy-and-fork (Option B refined)

User-proposed architecture (2026-06-01): rather than copy + simplify jtcontra_gfx
to make a private 005885 version, parameterize it instead so the same module
covers both chips. Our `jtddribble_5885.v` becomes a thin wrapper that:

  - Instantiates the parameterized base with MODE_5885=1
  - Translates schematic-named ports (NCPE, NXCS, DB, R[15:0], COL[4:0])
    to the base module's internal naming
  - Hides 007121-only outputs (top 2 bits of pxl_out, etc.)

This is architecturally cleaner than Option A (copy + fork) because:
  - One module, one source of truth
  - Bug fixes in the tile/sprite engine propagate to all consumers
  - Our wrapper exposes the schematic interface; the base module stays generic

### Three-step rollout

| Step | What | When |
|---|---|---|
| **1. Private copy** | Copy jtcontra_gfx + tilemap + obj into cores/ddribble/hdl/, add MODE_5885 parameter, write the wrapper. Original cores unaffected. | Phase 2 of 005885 build |
| **2. Promote to shared modules/** | Move the parameterized files to modules/jtkonami/ (or similar shared location). Update all 7 cores' files.yaml. Test all 7 still lint/sim. | After our private copy works |
| **3. Upstream to Jotego** | PR to consolidate. Requires confirmation that all 7 sister cores still pass regression tests with the parameterized version. | After (2) is stable |

We start with Step 1. Step 2 and 3 are follow-ups when we're confident the
parameterization is correct.

### Where MODE_5885 controls behaviour (inside the parameterized base)

Use `generate` blocks to gate the differences:

```verilog
parameter MODE_5885 = 0;   // 0 = full 007121 (default), 1 = 005885 subset

// Register decoder:
//   MODE_5885=1: 5 registers, only reg 3 (char_bank) and reg 4 (int_enable) active
//   MODE_5885=0: 8 registers with full feature set

// Tile code composition:
//   MODE_5885=1: hardcoded num = byte + attr[7:6]<<2 + attr[5]<<5 + charbank[1]<<10
//                (per MAME ddribble.cpp::get_fg_tile_info)
//   MODE_5885=0: Reg 4/5 per-bit mapping (jtcontra_gfx's current logic)

// ROM address width:
//   MODE_5885=1: rom_addr[15:0]   — external R16/R17 banking via PCB logic
//   MODE_5885=0: rom_addr[17:0]   — chip handles full address internally

// Color output:
//   MODE_5885=1: pxl_out[4:0] (top 2 bits forced to 0 — they're not on COL pins)
//   MODE_5885=0: pxl_out[6:0] (full COA[6:0])

// Disabled-when-5885 features (force inputs to 0):
//   strip_en, strip_col, strip_txt (strip-scroll registers in mmr[1])
//   narrow_en, layout              (mmr[3] screen-layout tricks)
//   extra_mask, extra_bits         (mmr[4] code-bit overrides)
//   code9_sel...code12_sel         (mmr[5] attribute-bit mapping)
//   nmi_pace                       (mmr[7] NMI rate select)
//   per-IRQ enable bits            (replaced by single int_enable in MODE_5885)
```

Estimated added complexity to jtcontra_gfx (in our private copy): ~80-120 lines
of `generate if (MODE_5885)` gating.

### Wrapper template (jtddribble_5885.v after Step 1)

Replaces our current Phase 1 shell. ~60 lines once written:

```verilog
module jtddribble_5885 (
    // SCHEMATIC-named ports (the ones we documented in Phase 0)
    input    [13:0]  A,
    input    [ 7:0]  DBi,
    output   [ 7:0]  DBo,
    input            NXCS, NRD, NREG, NEXR,
    output           NCPE, NCPQ, NEQ, NCK2,
    output   [15:0]  R,
    input    [ 7:0]  RDU, RDL,
    output           NIRQ, NNMI, NFIR, NCSY, NYSY,
    output   [ 4:0]  COL,
    output   [ 3:0]  VCB, VCD,
    output   [ 3:0]  BCB, BCD, BCF
    // ...other ports per Phase 0 port list...
);

// Polarity adaptation: the base module uses active-HIGH chip-select internally,
// the chip's NXCS pin is active-LOW
wire        cs_active   = ~NXCS;
wire [17:0] rom_addr_18;   // base module produces 18 bits; we discard top 2
wire [ 6:0] pxl_out_7;     // base produces 7 bits; we expose only lower 5

assign R   = rom_addr_18[15:0];   // 18-bit → 16-bit (PCB handles upper banking externally)
assign COL = pxl_out_7[4:0];      // 7-bit → 5-bit (top 2 are 007121-only attribute bits)

jtddribble_5885_7121_gfx #(
    .MODE_5885 ( 1 )                  // <-- this is the magic parameter
) u_chip (
    .rst       ( ~NEXR     ),
    .clk       ( ... ),
    .pxl_cen   ( ... ),
    // CPU bus
    .addr      ( A         ),
    .cpu_dout  ( DBi       ),
    .dout      ( DBo       ),
    .cs        ( cs_active ),
    .cpu_rnw   ( NRD       ),
    // CPU clocks/interrupts out
    .NCPE      ( NCPE      ),
    .NCPQ      ( NCPQ      ),
    .cpu_irqn  ( NIRQ      ),
    .cpu_nmin  ( NNMI      ),
    .cpu_firqn ( NFIR      ),
    // ROM bus
    .rom_addr  ( rom_addr_18 ),
    .rom_data  ( {RDU, RDL}  ),
    // Sync
    .NCSY      ( NCSY      ),
    .NVSY      ( NYSY      ),
    // Pixel
    .pxl_out   ( pxl_out_7 ),
    // VCB/VCD/BCB/BCD/BCF — direct passthrough since they exist on both chips
    .VCB       ( VCB       ),
    .VCD       ( VCD       ),
    .BCB       ( BCB       ),
    .BCD       ( BCD       ),
    .BCF       ( BCF       )
);

endmodule
```

Total wrapper size: ~70 lines including comments. Clean separation of concerns:
the schematic-facing interface (this file) doesn't know about 007121's
JTFRAME-style internals, and the base module doesn't know about ddribble's
schematic-naming conventions.

### Update to phase plan

| Phase | New action (replaces "copy + simplify") |
|---|---|
| **2** | (a) Copy jtcontra_gfx*.v to cores/ddribble/hdl/, rename to jtddribble_5885_7121_*.v; (b) add `MODE_5885 = 0` parameter (default = 007121 mode); (c) gate the differing logic with `generate if (MODE_5885)` blocks; (d) rewrite our `jtddribble_5885.v` to be a wrapper that instantiates the new file with `MODE_5885(1)`; (e) lint |
| **3** | Verify MODE_5885=1 produces 005885-compatible behaviour: write CPU patterns to VRAM via wrapper, check internal state |
| **4** | Test in sim: instantiate twice in `_video.v` (E16 + H16 layers), see if anything renders |
| **5** | Tile + sprite render verification against MAME reference output |
| **6** | Hook NCPE → main CPU `cen` (Option A wiring) |
| **7** | Promote to modules/jtkonami/ (after our copy is stable) |

The wrapper STAYS in `cores/ddribble/hdl/jtddribble_5885.v` permanently — that's
the right place for the schematic-facing interface. The parameterized base
module is what gets promoted to shared modules/.

---

## Build progress log (current as of 2026-06-01)

### ✅ Phases done

| Phase | Description | Result |
|---|---|---|
| 0 | Port list locked, schematic-grounded | 50+ ports documented above |
| 1 | jtddribble_5885.v shell, lint-clean | shell file in cores/ddribble/hdl/ |
| 2a | Add MODE_5885 parameter to base (declaration only) | `parameter MODE_5885 = 0;` in jtddribble_5885_7121_gfx.v |
| 2b | Add JTFRAME framework I/O section to wrapper | clk24, pxl_cen, prog_*, rom_ok, debug_bus, gfx_en, st_dout, flip, rom_cs added to wrapper port list in clearly-marked section |
| 2c | Instantiate base in wrapper with full port translation | wrapper now contains real video logic; lint clean; polarity translations (`cs=~NXCS`, `cpu_rnw=~NRD`) documented inline |

### ⏳ Phases pending

| Phase | Description | Status |
|---|---|---|
| 3a | First base-internal MODE_5885 generate block | **NEXT** — pick from: feature-disable gating (strip_en/narrow_en/layout/nmi_pace forced 0) OR tile-code composition |
| 3b-3f | Subsequent generate blocks | TBD |
| 4 | Verify MODE_5885=1 produces 005885-compatible behaviour in sim | not yet |
| 5 | Tile + sprite render verification against MAME reference | not yet |
| 6 | NCPE/NCPQ generation in wrapper | not yet (deferred until Phase 7 needs them) |
| 7 | Integrate wrapper twice in jtddribble_video.v (E16 + H16), priority mux, palette CS routing, Option A wiring (NCPE → main CPU cen) | not yet |
| 8 (deferred) | Promote jtddribble_5885_7121_* to modules/jtkonami/ — single source of truth shared with contra/labrun/comsc/flane/castle/mx5k. Update all 7 cores' files.yaml. | separate PR, after our copy is stable |

## Important architectural rule discovered in 2c discussion

**Wrapper-side gating vs base-internal gating** — not all MODE_5885 differences need a `generate` block in the base. Use the rule:

| If the difference is... | Gate where |
|---|---|
| **Only how the chip exposes bits at its output pins** (pin count, bit-width, polarity) | Wrapper — output adapter is exactly its job |
| **What the chip COMPUTES internally** (tile codes, register decoder, interrupt model, sprite list format, scroll RAM) | Base — wrapper can't fix wrong computation by output-shaping |

Examples already handled wrapper-side (no base changes needed):
- `pxl_out[6:5] → COL[4:0]` truncation (wrapper discards the top 2 bits)
- `rom_addr[17:16] → R[15:0]` truncation (banking external on real PCB)
- `col_cs` output ignored (005885 doesn't drive a palette CS)

Examples that REQUIRE base-internal gating:
- Tile code composition (007121's Reg 4/5 indirection vs 005885's hardcoded `code + attr[7:6]<<2 + attr[5]<<5 + charbank[1]<<10`)
- Interrupt enable model (007121's 3 separate enables vs 005885's single `int_enable` bit)
- Feature-disable bits (strip_en, narrow_en, layout, nmi_pace forced to 0 in MODE_5885=1)
- Sprite list format (if different)

The first base-internal `generate` work should be the FEATURE-DISABLE bits — smallest pattern, lowest risk:

```verilog
wire strip_en_eff  = (MODE_5885 == 1) ? 1'b0 : strip_en;
wire narrow_en_eff = (MODE_5885 == 1) ? 1'b0 : narrow_en;
wire layout_eff    = (MODE_5885 == 1) ? 1'b0 : layout;
wire nmi_pace_eff  = (MODE_5885 == 1) ? 1'b0 : nmi_pace;
```

Then change all downstream references from `strip_en` → `strip_en_eff` (etc.).
