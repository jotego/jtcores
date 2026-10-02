# Toobin' (Atari, 1988) — bring-up STATUS

Driver: `doc/toobin.cpp` (Aaron Giles). Deps mirrored: `atarijsa.{cpp,h}`, `atarimo.{cpp,h}`.
MAME note: *"The video sync chain is almost identical to System 2."* No existing Atari core
in JTCORES — this is a new hardware family.

## Machine config (the spec sheet)

- MASTER_CLOCK = **32 MHz** XTAL.
- **Main CPU:** M68010 @ 32/4 = **8 MHz**. `set_interrupt_mixer(false)` → raw IPL lines:
  - **IPL0** = scanline interrupt (programmed via `interrupt_scan` reg, ack at `0x8283c0`).
  - **IPL1** = JSA sound interrupt (`main_int_cb`).
- **Sound:** `ATARI_JSA_I` board (see Sound section). YM2151 + POKEY (NO OKI — that's JSA-II/III).
  `config.device_remove("jsa:tms")` → **no TMS5220 speech** populated on Toobin'.
- **EEPROM:** parallel 2804 (`lock_after_write`), 0x82a000-0x82a3ff, byte-wide (umask 0x00ff).
- **Watchdog:** 8 vblank counts.

## Video (rotated 270°, vertical monitor)

- Dot clock 32/2 = 16 MHz; raw 640×416 total, **512×384 visible**, 60 Hz.
- **Playfield:** TILEMAP 128×64, 8×8, **4bpp** (gfx0 `tiles`, RGN_FRAC(1,2)). 4 priority categories
  (`category = (data>>20)&3`), drawn in 4 passes. code=`data&0x3fff`, color=`(data>>16)&0xf`,
  flipXY=`data>>14`.
- **Alpha (text):** TILEMAP 64×48, 8×8, **2bpp** (gfx2 `chars`). code=`data&0x3ff`,
  color=`(data>>12)&0xf`, flipX=`(data>>10)&1`. Palette base 512.
- **Motion objects (sprites):** `atarimo` device, 16×16 4bpp (gfx1 `sprites`, RGN_FRAC(1,2)).
  Palette base 0x100. SLIP-based (1024 px/SLIP entry), linked list, swapped X/Y order.
  - **4 words (8 bytes) per entry; MOB RAM 0x800 = 256 entries.** Format (from `s_mob_config`):
    - word0: bit15 absolute-coord, bits[14:6] Y, bits[5:3] height-1 (tiles), bits[2:0] width-1
    - word1: bit15 vflip, bit14 hflip, bits[13:0] tile code
    - word2: bits[7:0] link (next entry index)
    - word3: bits[15:6] X, bits[3:0] color
  - **SLIP**: 1024 px per SLIP entry, linked list walked per scanline band; `:mob:slip` is a
    single 16-bit reg here (verified via MAME share dump). render swapped X/Y order, 1 bank.
  - X/Y scroll come from `0x828600/0x828700` (>>6); mob xscroll = pf xscroll, mob yscroll &0x1ff.
- **Priority merge** (screen_update): MO over PF unless `pri[x] && (pf&8)` (high-prio PF wins).
  Exact rule is in a PAL — *"not verified"* per MAME. Alpha drawn last, always on top.
- **Palette:** 1024 entries, RAM at 0xc10000. Format **xBGR-555**: R=`(w>>10)&31`, G=`(w>>5)&31`,
  B=`w&31`, scaled `*224>>5` then `+38` if non-zero. **bit15 = brightness/contrast enable**
  (per-pen), global intensity reg at `0x828300` (`~data&0x1f`/31).

## Main address map (global_mask 0xc7ffff)

| addr | what |
|---|---|
| 000000-07ffff | ROM (512 KB, 68010 code, ROM_LOAD16_BYTE interleave) |
| c00000-c07fff | playfield tilemap RAM (32 KB → 16K words) |
| c08000-c097ff | alpha tilemap RAM (mirror 0x046000) |
| c09800-c09fff | motion-object RAM (mirror 0x046000) |
| c10000-c107ff | palette RAM (mirror 0x047800) |
| 826000 | nopr (read at controls time — unknown) |
| 828000 | watchdog reset |
| 828101 | JSA main_command_w (byte) |
| 828300 | intensity_w |
| 828340 | interrupt_scan_w (scanline IRQ line #) |
| 828380 | mob SLIP reg |
| 8283c0 | scanline_int_ack_w |
| 828400 | JSA sound_reset_w |
| 828500 | EEPROM unlock_write |
| 828600 | xscroll_w |
| 828700 | yscroll_w |
| 828800 | input port "FF8800" (paddles + throw) |
| 829000 | input port "FF9000" (service / hblank / vblank / sound-ready) |
| 829801 | JSA main_response_r (byte) |
| 82a000-82a3ff | EEPROM (byte, umask 0x00ff) |
| 82c000-82ffff | work RAM (16 KB) |

## Inputs

- **FF8800** (active-low): per player, 4 paddle bits (R-fwd/L-fwd/L-back/R-back) + throw.
  P1 = bits 0x10..0x80 + throw 0x100; P2 = bits 0x01..0x08 + throw 0x200.
  → **dual rotary/paddle controls** — will need `JTFRAME_NOMULTIWAY`.
- **FF9000** (active-low): bit12 SERVICE, bit13 hblank, bit14 vblank, bit15 JSA main-to-sound ready.
  (also feeds JSA `test_read_cb` bit12).

## GFX layouts

- `pflayout` (tiles): 8×8 4bpp, planes `{RGN_FRAC(1,2)+0, RGN_FRAC(1,2)+4, 0, 4}` → planes split
  across the two ROM halves; 2 px/byte.
- `molayout` (sprites): 16×16 4bpp, same split-plane scheme, 8*64 bits/tile.
- `anlayout` (chars): 8×8 2bpp, planes `{0,4}`, 8*16 bits/tile.

## ROM regions / sets

- maincpu 0x80000 (8× 64Kb, 16-bit interleaved j/f pairs)
- jsa:cpu 0x10000 (1× 6502)
- tiles 0x80000 (8× 64Kb, straight)
- sprites 0x200000 (mix of 128Kb + 64Kb-with-ROM_RELOAD; reload mirrors low 64K into high half of each 128K slot)
- chars 0x4000 (1×)
- Sets: **toobin** (rev3, parent), toobine, toobing, toobin2, toobin2e, toobin1.

## Sound — Atari JSA-I board (`doc/atarijsa.cpp`)

JSA_MASTER_CLOCK = **3.579545 MHz** XTAL. Chips populated for Toobin':

| chip | clock | notes |
|---|---|---|
| M6502 | 3.579545/2 = **1.789 MHz** | sound CPU |
| YM2151 | 3.579545 = **3.579545 MHz** | FM, stereo, irq → 6502 |
| POKEY | 3.579545/2 = **1.789 MHz** | extra channels |
| TMS5220C | — | **removed** on Toobin' (`device_remove("jsa:tms")`) |

6502 IRQ = OR of (periodic timer `MASTER/4/16/16/14` ≈ 62.4 Hz) and YM2151 IRQ; ack at `0x2806`.

**6502 memory map (`atarijsa1_map`):**

| addr | what |
|---|---|
| 0000-1fff | RAM |
| 2000-2001 | YM2151 r/w |
| 2802 | sound_command_r (/RDP) — from 68k `0x828101` |
| 2804 | rdio_r (/RDIO) — coin/status inputs |
| 2806 | sound IRQ ack (r/w) |
| 2a00 | /VOICE (TMS write — N/C on Toobin') |
| 2a02 | sound_response_w (/WRP) — read by 68k at `0x829801` |
| 2a04 | wrio_w (/WRIO) — bankswitch + YM reset + OKI-ish ctrl bits |
| 2a06 | mix_w (/MIX) — analog mix levels |
| 2c00-2c0f | POKEY r/w |
| 3000-3fff | banked ROM (`cpubank`, selected by /WRIO) |
| 4000-ffff | ROM (fixed) |

Comm to main: 68k IPL1 raised by JSA `main_int_cb`; main-to-sound-ready status in `FF9000` bit15.

## CPU: 68010 program runs on a 68000 (use jtframe fx68k) — VERIFIED

The board has a M68010; JTCORES has no 68010 core, only fx68k (68000) via
`jtframe_m68k.yaml`. Static analysis of the assembled program image
(`ROM_LOAD16_BYTE` interleave of the 8 maincpu ROMs, 0x80000 bytes, reset
PC=0x408) with MAME `unidasm -arch m68010` shows it is fully 68000-compatible:

- **No 68010-only instruction is executed.** `movec`=0, `rtd`=0 in the entire
  image. Every `moves` / `move-from-CCR` (0x42cx) hit lands in DATA regions
  (verified: high dc.w/ILLEGAL neighbour density, monotonic 0x0eXX lookup
  tables decoded as `moves`, and absolute EAs like `$25001080`/`$31806480`
  outside the whole 0xC7FFFF map). None sit in real code.
- **Boot code is base-68000 only:** `move #$2700,SR` (move-TO-SR, legal on both;
  it is move-FROM-SR that the 68010 makes privileged — never used), `lea`,
  `clr`, `tst`, `dbra`, `btst`, `jsr`/`rts`.
- **Runs entirely in supervisor mode** (`$2700` ⇒ S=1, IPL=7) → the 68010
  privileged-MOVE-from-SR change is moot.
- **Exception-frame-format difference is irrelevant:** vectors 2,3,4,8,9,10,11
  (bus/addr/illegal/priv/trace/lineA/F) ALL point to 0x300 = `stop #$2700; nop`
  (dead halt, never RTE-resumes). Only the periodic scanline/sound IRQs RTE
  (5 `rte` total), using the plain frame that behaves identically on 68000.

Residual (timing, not correctness): 68010 CLR does no dummy read and has DBcc
loop mode + different cycle counts. Toobin syncs video via the programmable
`interrupt_scan` scanline IRQ, not cycle-counting, and its regs have no
read-side-effects, so fx68k @ the same 8 MHz is safe. **Decision: instantiate
fx68k (jtframe_m68k).**

## Rendering model: LINE-BASED raster, NO framebuffer

- Largest RAM is the 32 KB playfield *tilemap*; a 512x384 4bpp framebuffer would need ~192 KB —
  nothing that size exists in the map.
- Motion objects = Atari scanline sprite engine (`atarimo` `slipheight`/`maxperline`/`slipram`):
  per-scanline-band linked list → line buffer, not a framebuffer.
- FPGA generates pixels live from tilemaps + a sprite line buffer (cal50/kiwi/ddribble model).

## Memory plan (cfg/mem.yaml + macros.def) — BRAM fits MiSTer easily

**SDRAM** (ROM only; bank 0 = below BA1_START, so maincpu sits first at blob offset 0):

| Bank | region | size | blob off | bus (mem.yaml) |
|---|---|---|---|---|
| BA0 | maincpu | 512 KB | 0x00000 | main, 16-bit, aw18 |
| BA1 | jsa:cpu + chars | 64+16 KB | 0x80000 / 0x90000 | snd 8b aw16 / char 8b aw14 |
| BA2 | tiles | 512 KB | 0x94000 | tile 16-bit aw18 |
| BA3 | sprites | 2 MB | 0x114000 | obj 16-bit aw20 |

(addr_width is in 16-bit words per jtframe-mem.md: LSB=bit0 for 8-bit, bit1 for 16/32-bit. gfx kept
16-bit for now; FRAC-split / 32-bit interleave only if fetch starves on HW.)

**BRAM** (all CPU-visible RAM — SDRAM latency breaks the mem-test loop):

| name | region | size | aw (words) |
|---|---|---|---|
| ram | work RAM 0x82c000 | 16 KB | 13 |
| pf | playfield 0xc00000 | 32 KB | 14 |
| al | alpha 0xc08000 | 6 KB | 12 |
| mob | mob RAM 0xc09800 | 2 KB | 10 |
| pal | palette 0xc10000 | 2 KB | 10 |
| nvram | EEPROM 0x82a000 | 1 KB | 10 (8-bit) |

≈ 59 KB CPU/video BRAM (+ ~8 KB 6502 RAM + sprite line buffers when sound/video land).
Cyclone V has ~696 KB M10K → comfortable. `mist|sidi` gated off with `JTFRAME_SKIP`.

## External reference: Arcade-Atari-system1_MiSTer (info only, do NOT vendor)

GPL-3 VHDL core by d18c7db, schematic-faithful (chip-level, real Atari part numbers + schematic
sheet refs). **Mirrored locally (reference only, not synthesized) in `doc/atarisys1_ref/`** — see
that folder's README for the file→subsystem map and licensing. Toobin' schematics live in
`doc/Toobin.pdf` (gitignored, maker IP; we work from screenshots).
System 1 ≠ Toobin' (System-2-ish), but the **motion-object engine, tilemaps, palette
and sync chain are the same Atari lineage** — use as behavioral reference / cross-check, then write
fresh Verilog in jtframe style (jotego convention; also it is VHDL). Points us at the real schematics:

- **SYNGEN** (137419-103, SP-277): clock/sync gen, has the exact H-counter timing diagram
  (MCKR/1H/2H/4H/2HDL) → pin down jtframe_vtimer (vtimer mismatch moves sprites tens of lines).
- **GPC** (137419-101, SP-277): Graphic Priority Control = the priority merge MAME marks
  "not verified... in a PAL" (factors LBPRI/LBPIX/ANPIX/PFPIX/PFPRI). CRA = f(PFX,MPX,APIX,pri).
- **MOHLB** (SP-286 sheet 7): Motion Object Horizontal Line Buffer (sprite line buffer).
- **SLAGS** (137415-101, Marble Madness SP-276): graphics shifter (tile/sprite pixel serializer).
- **PFHS** (137419-104): playfield horizontal scroll.
- **RGBI**: "Intensity*Color/16" LUT — relates to Toobin' palette brightness (bit15) + intensity reg.
- **leta_rep / quad** (JROK LETA, freeware): roller/paddle **quadrature** decode → maps MiSTer
  analog/digital inputs to Toobin's quadrature paddle bits (FF8800).

Schematic sets cited: SP-276 (Marble Madness), SP-277, SP-280, SP-286, SP-298. Toobin' is its own
System-2-class board, so its customs/part-numbers differ — prefer Toobin'/System-2 schematics when
found. **Not in scope from System 1:** SLAPSTIC (Toobin' has none), cartridge board, the System 1
audio board (Toobin' = JSA-I). The core also has known unsolved bugs (see its README).

## BOOT TRACE — CPU runs, ~45K instructions match MAME (2026-06-27)
Loop: MAME `traces/main_boot.tr` (956K instr) vs FPGA `toobin_main_fpga.tr` (probe in main.v),
diffed by `ver/toobin/verify_main_boot.sh` (subsequence match, handles 68k prefetch).
- **Sim invocation:** `FRAMES=300 ROMS_HOST=~/.mame/roms-local ./sim-core.sh toobin toobin -load
  -d JTFRAME_SIM_SKIP_VSIZE`. `-load` = full ROM download (else it's shortened to 32 bytes → only
  the reset vector loads, CPU reads 0). `JTFRAME_SIM_SKIP_VSIZE` = bypass the frame-3 video-size
  check (else `break` kills the sim before boot). ROM transfers by ~frame 136.
- **Reset vector + boot sequence reproduce MAME exactly** (SSP=0xfffffe, PC=0x408, palette clear...).
- **BUG FOUND+FIXED — A22 mirror decode:** POST tests work RAM via its mirror `0xffc000` (A22=1),
  but I'd split peripheral/video on A22. Real HW partial-decode makes A22 a don't-care (MAME mirror
  0x450000); A17 distinguishes (peripheral A17=1, video A17=0). Fixed → 44898→45151 instr.
- **BUG FOUND+FIXED — vtimer 9-bit H overflow:** htotal 640 > 511 (H is [8:0]). Clamped <=511 for
  boot (width wrong, vsize skipped). TODO real video: half-rate H or HJUMP (SYNGEN sheet).
- **BOOT NOW MATCHES MAME for 360,750 instructions** (was 45K). The fix: **service/status bit
  polarity was inverted.** `btst #4,$ff9000` is a BYTE read (even addr → high byte) so bit4 = WORD
  bit 12 = the SELF-TEST switch (0=ON). jtframe `service` is active-low (idle=1) and the schematic
  map marks FF9000 bits "0=true", so they take NO inversion: `inp_din[12]=service, [13]=LHBL,
  [14]=LVBL, [15]=1`. With `~service` the FPGA thought self-test was ON and dived into the test menu.
  This cleared the ENTIRE POST RAM/ROM suite. (Also: the work-RAM "stale read" I chased was a
  data-PROBE artifact — a cycle dump proved the BRAM is correct. cpu_din left combinational; fine.)
- **CPU BRING-UP ESSENTIALLY DONE — boot reproduces MAME through POST + ROM checksum into the
  post-boot loop @0x1aa0** (FPGA reaches the same late PCs as MAME, same proportions). The "checksum
  divergence @360751" was a VERIFY-WINDOW artifact (the checksum loop is ~768K PC fetches/run, far
  bigger than the window). The ROM/SDRAM data is correct — proven by a cycle-level $display
  (`rom_ok=1 → romdata=0300` at the byte the romrd probe falsely flagged).
- **LESSON (3 self-inflicted this session): my data-bus `$fwrite` probes capture at unreliable
  moments → phantom "stale reads" (work RAM, romrd 0x4e, checksum). The cycle-level `$display`
  (RAMDBG/ROMDBG) is the trustworthy tool — use it before believing a custom data trace.**
- **SCANLINE IRQ (IPL0) IMPLEMENTED from the schematic gates and WORKING** — 9-bit programmed line
  (`intline_reg<=cpu_dout[8:0]` on `/INTLINE`; low6=LS174A, high3=SOS-1 spare latch) compared EQUAL
  to `vdump` (the cascaded 21K/22L LS85, A=B only), latched in a set/clear FF (set on match, clear on
  `/IRQACK` 0x8283c0). `IPLn={1'b1,1'b1,~scanline_irq}` (IPL1 sound still stubbed). The CPU now enters
  the L1 handler @0xde8 (635× in 250 frames) and services it → boot is past the @0x1aa0 delay into
  the interrupt-driven game phase. Lint clean.
- **NEXT: (a) capture a longer MAME trace (>2s) to diff the IRQ-driven phase apples-to-apples and
  confirm the IRQ rate/timing matches (raster splits?); (b) VIDEO bring-up (playfield via SOS-1
  behavior + jtframe_tilemap, then alpha, then atarimo SLIP sprites + GPC priority + RGBI palette).**
- **MEMORY MAP PAGE obtained (doc/Toobin.pdf) — CONFIRMS the entire address decode** (work RAM
  A23·A17·A15·A14 with A22/A16/A18 don't-care; alpha+MO one 8KB block A23·A22·~A17·~A16·A15; MO split
  at C09800 via A12·A11 = verify #17 CONFIRMED; playfield, palette, EEPROM all match my HDL). Also gives
  exact FF9000 bit positions + register map (FF8300 intensity etc.) for later.
- **DIVERGENCE ROOT-CAUSED (data-bus probe, toobin_data.tr):** NOT decode. The POST work-RAM verify
  (region #0, walks each addr with a bit pattern, write-then-read) gets **stale reads** at the high end
  (e.g. `W ffff0c 003f` → `R ffff0c 000f` = value from 2 writes ago). Low work RAM is perfect; the test
  uses register returns (no stack collision); BRAM is correctly sized (jtframe_ram16 AW=13, 8K words).
  → **read-data-path / BRAM-latency RACE:** work-RAM reads have no DTACK wait (`bus_cs=rom_cs` only) so
  the CPU sometimes latches `cpu_din` before the BRAM output settles.
  NEXT: waveform the failing read; FIX candidates: add BRAM regions to a 1-cycle bus_busy/DTACK wait,
  or make the cpu_din read mux combinational. (Probe `data_sp` tracer is in main.v under SIMULATION.)

## HDL scaffold — CPU spine LINTS CLEAN (2026-06-25)
- `hdl/jttoobin_main.v`: fx68k @ 8 MHz + schematic-verified address decode + register latches
  (scroll/intensity/slip/int-scan/sound-cmd) + input mux + boot-trace PC probe + NOMAIN stub.
- `hdl/jttoobin_game.v`: top + jtframe_vtimer + black-video & silent-sound stubs; gfx/sound SDRAM
  buses idle. `cfg/files.yaml`, `cfg/msg` added.
- `./lint-core.sh toobin` → 0 errors, 0 warnings in toobin code (2 remain in jtframe_debug_ctrl.v,
  framework, from the 512 width).
- **Stubbed (deliberately) for the boot trace:** IRQ (IPLn idle), paddle inputs (idle 0xffff),
  video (black), sound (silent). The boot trace tells us which to implement first.
- Config bugs fixed this pass: mem.yaml addr_width = log2(BYTES) not words; macros.def inline
  comments break integer macros; needed JTFRAME_PXLCLK.
- **NEXT: boot trace** (cpu-boot-trace skill) — sim → toobin_main_fpga.tr vs MAME boot trace, diff.

## Schematic parse progress (doc/Toobin.pdf)
- CPU/PROCESSOR sheets → `doc/SCHEMATIC_CPU.md` (CPU, reset/watchdog, IRQ, buffers, DTACK).
- Decode/ROM sheets → `doc/SCHEMATIC_DECODE.md` (full memory map — matches MAME register map exactly).
- ✅ **SLAPSTIC `SLAPSTK4` is NOT STUFFED on Toobin'** (footprint present, chip absent) → no banking,
  flat linear ROM = MAME. We do NOT implement a slapstic. (Resolved a feared MAME discrepancy.)
- New vs MAME: `/LETA`@0x826000 is a real select (MAME stubs it `nopr` "who knows"); intensity=`/ZLATCH`,
  slip=`/SLINKPTR`. No PAL in the CPU/decode logic (all LS139/138/20 TTL).

## Open questions for HW analysis (schematics pending)
- Exact PF/MO/ALPHA priority PAL equation (MAME marks it "not verified").
- SLIP / motion-object link-list timing vs scanline.
- `0x826000` read purpose.
