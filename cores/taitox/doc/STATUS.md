# Superman core — status as of 2026-05-18 (overnight session)

> **Session log (autonomous):** went from "scaffold lints clean" to "68k
> boots, sound CPU runs, palette path verified, blocked on C-chip
> uPD78C11". See `## Session diary` at the bottom.


This file is a continuity note. It captures where the core is, what works,
what's blocked, and what to tackle next so a future session (human or AI)
can resume without re-deriving everything.

## What works

- **Scaffold:** `cores/superman/` created from `kiwi` template via `new-core.sh`.
- **Lint:** clean for `superman`. The one remaining warning is inside `jt10.v`
  (jt12 module's adpcma_bank width mismatch — upstream issue, not ours).
- **Sim harness:** `ver/game/sim.sh` + `save.mame` in place; `./sim-core.sh
  superman superman` runs end-to-end via verilator and produces a per-frame
  JPEG sequence + MP4.
- **68k spine:** `jtsuperman_main.v` instantiates `jtframe_m68k` (FX68K) at
  8 MHz via `jtframe_68kdtack_cen` (num=1/den=6 from 48 MHz). Full Superman
  address decoder per MAME `taito_x.cpp` lines 620-642. IRQ 6 from V-blank
  via autovector (VPAn pulled low at FC=7, A[3:1]=6).
- **BRAM-backed RAMs in `_main.v`:** work RAM (16 KB @ 0xF00000), palette
  (4 KB @ 0xB00000), VRAM (2 KB @ 0xD00000), object RAM (16 KB @ 0xE00000),
  all dual-port (`jtframe_dual_ram16`). Port B is exposed in main.v's port
  list and currently tied to zero in `game.v` — the video subsystem will
  consume it once adapted.
- **TC0140SYT** (`jtsuperman_syt.v`, 232 lines): full 68k↔Z80 protocol — 4-bit
  master port, 8-bit slave port at 0xE200, auto-incrementing 4-bit index, two
  16-bit data words, 4-bit status, NMI enable, software reset, Z80 memory
  decoder, ROM bank register at 0xF200. Includes HLE "echo" that immediately
  copies slave_data → master_data on master writes (so the 68k's status-poll
  loops complete even before the Z80 catches up). This HLE can be removed
  once the Z80 is fully verified.
- **Sound subsystem** (`jtsuperman_snd.v`): real Z80 @ 4 MHz
  (`jtframe_sysz80` with 8 KB internal RAM), real YM2610 via `jt10`,
  ADPCM-A ROM access through `mem.yaml`'s `adpcma` bus.
- **Verified boot trace:** with ROMs from `~/.mame/roms/superman.zip`, the
  68k correctly fetches the reset vector (`SSP=$3FFE, PC=$3EF0`), runs the
  init code, passes the memory test (verified against MAME via debug script
  `cores/superman/ver/game/ballbros/trmain.mame`).

## What's blocked

### The C-chip wall

Superman cannot complete its boot sequence without the Taito C-chip
(MAME's `taito_cchip_device`). The chip is at 0x900000-0x900FFF on the
68k bus:

- 0x900000-0x9007FF — shared RAM (1 KB banked, 2 KB total per F2 docs)
- 0x900800-0x900FFF — ASIC registers

What the 68k expects from the C-chip:

1. **Magic signature "GWK"** at shared-RAM bytes `$001/$003/$005` (=
   `0x47/0x57/0x4B`). The 68k spins at `0x2C16` until it reads these. We
   currently HLE this in `_main.v` (`cchip_hle_byte`).
2. **Ready flag = 0x01** at ASIC byte `$903`. The 68k spins at `0x2AE2`
   until it reads 1. HLE returns 1 (same `cchip_hle_byte`).
3. **bit-set / bit-clear of `$900007`** (shared RAM byte): the 68k toggles
   bits 2 and 3 there as a "do something" handshake. The C-chip's MCU
   reacts and eventually writes to **68k work RAM at `$F01CCE`** to
   indicate completion. Without that write, the 68k spins at `0x4210`.
4. **Periodic IRQ 6 to the 68k** via the C-chip's INT timer output. (We
   currently substitute V-blank, which fires regularly enough that the
   IRQ count itself isn't the blocker.)
5. **Joystick/coin inputs** read by the MCU on its PA/PB/AN ports and
   surfaced to the 68k via shared RAM at offsets that only the MCU code
   knows.

**The MCU is uPD78C11 (NEC),** not HD6305 (Motorola). `jtcores` has
`jt6805` (M6805) but **no uPD78xx core**. Writing one from scratch is a
weeks-long project — out of scope tonight.

**Possible paths forward**, in increasing effort:

1. **Behavioral HLE** — implement just enough of the C-chip's observable
   behavior to satisfy Superman. Needs:
   - Shared-RAM BRAM (2 KB)
   - Static GWK signature
   - Mirror PA→shared RAM[$XX], PB→shared RAM[$YY], AN→shared RAM[$ZZ]
     (offsets to be determined by disassembling `b61_11.m11`)
   - Set a "ready" pattern (writes $1CCE = nonzero) shortly after boot
   - Generate IRQ 6 with the right cadence (~~ 60 Hz)
2. **Disassemble b61_11.m11** (uPD78C11 + EPROM) — gives the exact
   protocol. The EPROM is at MAME ROM region `cchip:cchip_eprom` and is
   already loaded into our SDRAM bank 3 via `cfg/mame2mra.toml`. A
   uPD78C11 disassembler exists in standard tooling (e.g. unidasm).
3. **Build a uPD78C11 core** in `modules/jt78xx/` — large but reusable
   for other Taito games (Bonze Adventure, Operation Wolf etc. all use
   the C-chip).

The HLE path is the right next step. Estimated ~400-600 lines of HDL
once the MCU code has been disassembled and behavior catalogued.

### Video — pixel-perfect against MAME

`jtsuperman_game.v` instantiates **two `jtsuperman_obj` engines** (FG
with `page=0`, BG with `page=1`) directly, with a per-VBLANK FSM that
loads the X1-001A spritectrl bytes (m_spritectrl[0..3]) and 16-column
scroll arrays from VRAM. The full kiwi-style chip wrapper
(`_gfx.v / _video.v / _tilemap.v`) that was originally copied over has
been **deleted** — Taito X has no tilemap, and the chip-internal DMA
that the wrapper modeled is N/A on the m68k bus (the CPU writes
spritecode directly to OBJ-RAM at 0xE00000-0xE03FFF). The current
direct-instantiation approach renders pixel-perfect against all 17
MAME burst captures in `ver/superman/sim_results/`.

## Files & structure

```
cores/superman/
├── README.md              kiwi-derived prose, needs rewrite
├── cfg/
│   ├── files.yaml         lists per-core + jtframe + jt12 sources
│   ├── macros.def         Superman macros (8MHz 68k, 4MHz Z80, 384x240)
│   ├── mame2mra.toml      sourcefile taito_x.cpp, machines = superman/u/j
│   ├── mem.yaml           SDRAM banks: main (ro), snd+adpcma, scr+obj
│   └── msg
├── doc/                   reference dumps (read-only)
│   ├── taito_x.cpp        MAME driver snapshot
│   ├── taitosnd.cpp       TC0140SYT register reference
│   ├── seta_x1-001.md     X1-001 register reference
│   ├── seta001.cpp        Seta sprite chip notes
│   ├── tc0140syt.sv.ref   F2 reference RTL (GPLv2)
│   ├── tc0030cmd.sv.ref   F2 C-chip HLE stub
│   └── STATUS.md          THIS FILE
├── hdl/
│   ├── jtsuperman_game.v   top wrapper — main + syt + snd + 2x obj engines + vtimer
│   ├── jtsuperman_main.v   68k + BRAMs + address decoder + C-chip HLE
│   ├── jtsuperman_syt.v    TC0140SYT (with HLE echo path)
│   ├── jtsuperman_snd.v    Z80 + jt10 + SYT slave wiring
│   ├── jtsuperman_obj.v    kiwi-derived sprite scanner, instantiated 2x by game.v
│   ├── jtsuperman_draw.v   pixel extraction inside _obj
│   └── jtsuperman_colmix.v palette + RGB mux
└── ver/game/
    ├── sim.sh             jtsim wrapper
    ├── save.mame          memory regions to dump
    └── ballbros/          ver dir + MAME debug script reference
```

## How to run

```
# from cores/superman/ on cabal branch:
cd /Users/andreabogazzi/develop/jtcores
FRAMES=80 ./sim-core.sh superman superman
# outputs cores/superman/ver/game/frames/*.jpg + superman_sim.mp4
# Edit cores/superman/hdl/jtsuperman_main.v to adjust CPU-side trace

# Capture MAME reference trace:
./mame superman -debug -debugscript /tmp/trsuperman.mame -nothrottle \
    -video none -seconds_to_run 1 -str 1
# (See cores/superman/ver/game/ballbros/trmain.mame for the watchpoint
# template; clone to cores/superman/ver/game/superman/ for Superman.)

# Disassemble around any stall PC:
echo 'focus maincpu
dasm /tmp/out.asm, 0xADDR, 0x80, 1
quit' > /tmp/d.mame
./mame superman -debug -debugscript /tmp/d.mame -nothrottle -video none
```

## Roadmap (2026-05-20 — agreed direction)

**Phase 1 — Make the game fully playable.** This is the immediate
focus. The bring-up gets:
  - Coin insertion + input mapping working all the way through to
    in-game action
  - Sound output reaching the speaker
  - Title → service menu → attract → gameplay path verified end-to-end
  - Any remaining MAME-vs-FPGA divergences for the captured 17 scenes
    investigated only if they actively block gameplay

The existing Superman video pipeline (2× `jtsuperman_obj` instantiated
directly from `jtsuperman_game.v` with a per-VBLANK FSM that captures
m_spritectrl[0..3] + scrollx/scrolly arrays from VRAM) stays as is
for Phase 1. It renders pixel-perfect against every burst we've
captured, so don't churn it.

**Phase 2 — Implement a proper Seta X1-001A chip module.** Deferred
until Phase 1 lands. When taken up, this is a real chip-equivalent:
  - Self-contained module that owns spritectrl, scrollram, OBJ-RAM
    interface, FG/BG draw arbitration
  - Matches MAME's `seta001_device` semantics (draw_foreground +
    draw_background paths, bank-swap, startcol, screenflip, upper
    register, bg-flag transparency, etc.)
  - Usable by both Superman (Taito X, m68k bus) and the kiwi family
    (TNZS et al., Z80 bus) via a `CPUW` parameter
  - Replaces the current direct-instantiation glue in
    `jtsuperman_game.v` with a single module instance

This is a multi-day refactor that doesn't add user-visible features
on top of Phase 1. It pays off architecturally (one place for Seta
chip semantics, easier to add cocktail flip / bank-swap / dynamic
numcol later) but isn't a Phase 1 dependency.

### Known hardware-side bugs (post 2026-05-21 deploy)

**V-flip viewport offset.** When the game enables cocktail flip (V/H
flip via the X1-001A's `bg_ctrl0_r[6]`), the framebuffer's pixels
render flipped correctly per-cell but the **viewport position is
wrong**: a strip of the original-orientation render leaks through at
the bottom of the screen (the un-flipped "HIGH SCORE 500000" footer
and "1UP/2UP" markers stay visible while the rest of the image
flips).  User has screenshots.  Likely root cause: the FG/BG line-
buffer-read address path (or the framework's V-flip offset macro
`FLIP_OFFSET` we pass to `jtframe_obj_buffer`) doesn't account for
the difference between MAME's vdump 8..247 visible window and our
shifted vdump 15..254.  When V-flip is active the reflection axis
ends up offset by those 7 lines.  Address: pick this up when sound
work pauses; the kiwi engine's `flip` parameter is the suspect path.

**Background 1-px vertical stripes (still under investigation).**
Bug confirmed on MiSTer HDMI output, NOT reproducible in verilator
sim (which doesn't model the analog DAC or HDMI scaler).  Suspected
root cause: H rate at 14.42 kHz (was 7.6% below the 15.625 kHz NTSC
standard) caused the MiSTer's HDMI scaler to interpolate poorly.
Mitigation in flight: switching to PXLCLK=8 with a 512×272 vtimer
gives an exact 15.625 kHz H rate (commits `d024792a6` /
`a92349136`).  If the stripes persist after this, the cause is in
the HDL render path and we'd need a sim repro before going
further.

### Sound bring-up — TC0140SYT fixed, dispatcher copy verified, music dispatch blocked

`docker run` sim instrumentation traced the FM-music-silent path end-to-end
during this session.  Findings (as of 2026-05-21):

**Working ✓**

  * Z80 boots, runs init at PC=0008/000B (NMI disable), 027x (boot ack
    via slave_comm submode=0 then submode=1 sets PORT01_FULL_MASTER),
    then idles at the status-poll loop (PC=006D/02D0).
  * 68k SYT routine reachable: probes at `$2DF6` (send_to_syt) and
    `$2E0C` (status poll) fire.
  * 68k status reads at master_idx=4 correctly return status=0x04
    (bit 2 set after Z80 ack) — Z80-alive check passes.
  * `bank_68k` switches via the 68k's `$2BC2` routine (`move.b D7,
    $900C01`).  Transitions 0→7→6→…→0 during RAM init, then 0→2→1
    around the dispatcher copy, then 1→0 after.
  * C-chip MCU writes the 256-byte dispatcher payload to
    `shared_ram[bank=1][0..255]` correctly — bit-perfect against
    MAME's reference (`/tmp/superman_dispatcher_payload.bin`).
  * 68k's copy loop at PC=`$2C50` reads from `$900001` while
    `bank_68k=1` and writes the proper payload (`4E 56 00 00 48 E7
    01 00 …`) to work RAM at `$F01B20..$F01C1F`.

**The block** is one layer further up:

  * **The 68k never executes the dispatcher code from work RAM.**
    Probes for `ram_cs & main_addr==18'h00D90` ($F01B20 dispatcher
    entry) and `==18'h00DB8` ($F01B70 enqueue point) **never fire**.
  * MAME's 68k reaches `jmp ($1B20,A5)` at `$2D8A` (= jump to
    `$F01B20` if A5=$F00000) and the dispatcher runs through to the
    enqueue at `$F01B70`, queuing music byte `0xEF` to
    `($1c40,A5)..($1c44,A5)`.  Our 68k either never reaches `$2D8A`,
    or reaches it with A5 set differently so the indirect jump goes
    elsewhere.
  * Without entering the dispatcher, the music queue stays empty.
    The 68k's dispatch routine at `$2D8E..$2DEE` reads the empty
    queue and exits via the empty-queue branch (`beq $2DEE`).  No
    `send_to_syt(0, music_byte)` write to the SYT master port =
    Z80 never receives a music command = YM2610 channels stay
    TL=$7F muted = `test.wav` silent.

**Pre-fixes that landed this session**

  * `jtsuperman_syt.v` — falling-edge bus capture matching the
    `jtrastan_pc060_unit` pattern (cores/rastan/hdl/jtrastan_pc060.v).
    Without this, the 68k bus's S2→S4 ASn-vs-LDSn skew fired a
    phantom `master_comm_r` on every write, auto-incrementing
    `master_idx` and clearing `status_reg[2]` right after the Z80
    set it.  Commit `31b3f9360`.
  * Vtimer 416×251 grid for 57.46 Hz refresh, VS_END < VCNT_END
    fix.  Commits `2fa9f3d10` / `9cc49fa11`.
  * Service polarity fix (`~service` → `service` in `cab_in2`).
  * TC0140SYT idx 4 = reset (was idx 7); HLE echo + status patches
    removed.

**Next steps when sound work resumes**

  1. Add a probe for PC=`$2D8A` itself to confirm if it's reached.
  2. If reached, dump A5 at that instant — if A5 != `$F00000`, find
     what's setting it wrong.
  3. If A5 is correct but jmp still doesn't enter the RAM
     dispatcher, suspect 68k FX68K exception/IRQ trap behaviour or
     bus-arbiter dropping the RAM fetch.
  4. The sim-only diagnostic probes are kept in `_main.v` and
     `_cchip.v` under `ifdef SIMULATION` (CALLER probes for $2BC6,
     $2C54, $2C68, $2DF6, $2E0C, $F01B20, $F01B70; DISPATCH_W,
     CCHIP_BANK_W, BANK_68K, BANK_MCU, MCU_W_SRAM, SLAVE_PORT_W,
     SLAVE_COMM_W, MASTER_COMM_R).  These are ready to use for
     follow-up sessions.

### m_spritectrl[1] — deferred until other Seta X1 games land

`bg_ctrl1_r` (m_spritectrl[1] in MAME's seta001.cpp) is currently
**not loaded or decoded** in our HDL. It carries three feature bits:

  - bits[3:0]: numcol (BG column iteration count, 1 → 16 special-case)
  - bit  5:   suppress EOF sprite-RAM buffer copy
  - bit  6:   active sprite bank (XOR'd with bit 5 in MAME's seta001
              line 274 / 379 for front/back-buffer swap)

For Superman specifically the register is STATIC at 0x21 across the
entire attract loop — verified by MAME trace at
`cores/superman/ver/superman/mame_scripts/trace_spritectrl.lua`,
which captured exactly one write at frame 0 (mPC=0x003F16, value
0x21) and zero subsequent changes. 0x21 decodes to numcol=16,
no-copy, bank-0 — i.e. all three features at their no-op default —
so our hard-coded BG render matches MAME pixel-for-pixel without
needing the register.

**This may NOT hold for the other Seta X1 games.** When bringing up
Ballbros, Gigandes, Daisenpu, Kyustrkr or any sibling on this engine,
the FIRST step is to re-run the spritectrl trace on that game
(`./mame -rompath ... <setname> -autoboot_script trace_spritectrl.lua
-seconds_to_run 174 -video none -sound none -nothrottle`) AND on a
gameplay scene (coin+start injection or burst-capture from a
gameplay save state) to see whether bit 6 toggles per frame or
numcol drops below 16. If yes, the work to do is:

  1. Restore the load_state==19 read of word 0x301 in
     `jtsuperman_game.v` (the FSM was stripped in commit f2504bf7e).
  2. Decode in the BG path:
     - `numcol_eff = (bg_ctrl1_r[3:0] == 1) ? 5'd16 : bg_ctrl1_r[3:0]`
     - `bank_swap = (bg_ctrl1_r ^ ~(bg_ctrl1_r<<1)) & 8'h40`
     - Add the bank offset to the kiwi engine's OBJ-RAM address path.
  3. Implement the end-of-frame OBJ-RAM copy FSM
     (0x800 bytes between halves during VBLANK, direction per ctrl1[6]).

Step 3 is the real engineering cost — a small FSM streaming through
the OBJ-RAM dual-port BRAM during the vblank window. It's why we
defer until a sibling game actually exercises it.

## Suggested next session

1. **Disassemble `b61_11.m11`** (the uPD78C11 EPROM) using a 78C11
   disassembler. Identify:
   - What memory offsets in shared RAM (0x900000-0x9007FF) the MCU
     writes joystick/coin state to.
   - When the MCU writes to byte `$007` and reads bit-set/clear from 68k.
   - The exact IRQ generation timing.
2. **Write a behavioural `jtsuperman_cchip.v`** (no uPD78C11 core) that:
   - Owns the shared RAM as a real BRAM.
   - Pre-fills GWK at boot.
   - Mirrors `cab_in0/1/2` to the shared RAM offsets identified in #1.
   - Generates IRQ 6 every frame.
   - Acks the `$900007` bit toggles by writing `$F01CCE` non-zero shortly
     after.
   - **Important:** the actual stall in the boot trace is at `0x4210`,
     and the loop is *waiting for `$F01CCE` to become ZERO*, not
     non-zero. The boot init probably sets `$F01CCE = N` and the C-chip
     IRQ handler counts it down. So our HLE needs to clear `$F01CCE`
     periodically (e.g. once per frame) or detect the bset/bclr at
     `$900007` and clear it then.
3. **Rip out the HLE in `_main.v` and `_syt.v`** (`cchip_hle_byte`, SYT
   echo) once the real C-chip is in.
4. **Video pipeline**: ✅ done — two `jtsuperman_obj` engines instantiated
   directly from `game.v`, pixel-perfect against MAME burst captures.
5. Boot Superman past the title screen.

## C-chip integration milestone (2026-05-18, post-overnight)

**The real Taito C-chip is in.** Fulvio (collaborator) wrote a NEC
uPD78C11 CPU core derived from MAME's `cpu/upd7810/` (BSD-3-Clause,
3980 lines of behavioural Verilog) plus a full wrapper integrating the
4 KB internal mask ROM + 8 KB shared SRAM + 4 ASIC regs + bank
registers + 8 KB game EPROM + 256 B MCU IRAM. Originally written for
Rainbow Islands; I adapted his wrapper for Superman's 68k memory map
(1 KB shared RAM at `$900000-$9007FF` + 1 KB ASIC at `$900800-$900FFF`,
no 68k-side bank register), internalised the EPROM as a BRAM loaded
via `$readmemh`, dropped the Rainbow-specific `BRING_UP` scaffolding,
and removed the `EXTRA_VERSION` Rainbow set-id parameter.

Files:
- `hdl/jtsuperman_upd78c11.v` — Fulvio's CPU core (renamed from
  `jtrisle_upd78c11`, otherwise untouched).
- `hdl/jtsuperman_cchip.v` — Fulvio's wrapper, adapted as described.
- `hdl/mask_rom.mem` — the 4 KB Taito C-chip internal firmware
  (shared across all C-chip games; provenance: MAME's distribution).
- `hdl/cchip_eprom.mem` — Superman's `b61_11.m11` (8 KB EPROM)
  hexified.

The HLEs in `_main.v` (hardcoded GWK signature + ASIC ready=1) and
`_syt.v` (master-data echo) become dead-letter for the C-chip path
once real boot succeeds — but they remain in the code for now so the
sound side keeps working until Superman exercises both subsystems
end-to-end.

### What sim confirms

- Lint clean (only upstream `jt10.v` width warnings remain).
- FRAMES=10 sim runs to completion in ~1:26.
- MCU executes: `dbg_retire` counter showed **1.6 million instructions
  retired** during the 10-frame sim. The MCU is real, not a stub.
- 68k still progressing through the work-RAM memory-test patterns
  (PCs `0x3F7E-0x3FAC`) — same boot phase we reached before, so the
  C-chip didn't break anything.
- Sim is ~10× slower per frame than the no-MCU version (MCU runs at
  the same 48 MHz `clk` rate as the rest of the design). Reaching the
  C-chip handshake region (`0x2C16` GWK check) would take roughly
  FRAMES≥80 → ~14 min wall time.

### Known limitations / next-session knobs

- ADC conversion is stubbed in Fulvio's core (the `port_cr0/1/2/3`
  inputs pass through directly). Superman's MCU code reads `CR0/CR1`
  and routes the AD channel; if the protocol genuinely depends on
  analog values we'd need real ADC modelling. Likely OK for now —
  the IN2 byte fed via `cab_in2` is digital.
- Timers and serial peripherals are stubbed. Same disposition.
- `int_n` from the wrapper to the 68k is tied to 1 (no IRQ from
  C-chip yet). We still rely on the V-blank-driven IRQ-6 in `_main.v`;
  that path stays until Fulvio's wrapper grows its IRQ latch.
- The MCU runs at every 48 MHz tick → big sim cost. Adding a clock
  enable for the MCU (e.g. divider 1/4 → 12 MHz, the real chip rate)
  would speed sim 4× and is the cheapest perf knob.

## Session diary (2026-05-18, overnight, autonomous)

A blow-by-blow of how the core got into its current state, to short-cut
"why did you do X" archaeology next time.

1. **Refocus on Superman.** mame2mra.toml `machines` list narrowed to
   `superman`/`u`/`j`; `doc/custom.xml` regenerated from local MAME for
   those three sets only (was 18 cousin-game entries before).
2. **First sim with real Superman ROM.** 68k boots from reset vector
   `SSP=$3FFE, PC=$3EF0`, runs init code, enters infinite loop at
   `0x1CC0-0x1D42`. Disassembly reveals it's the **memory-test failure
   display** (writes ASCII hex of the failing address to object RAM at
   `$E000F2`). Test code at `0x3F70` showed `A0=$F00000` — work RAM
   bytes weren't reading back correctly.
3. **Moved RAMs from SDRAM to BRAM** inside `jtsuperman_main.v` —
   `jtframe_dual_ram16` instances for work / palette / vram / oram.
   `mem.yaml` simplified to SDRAM-only banks (no `ram` bus, no `cchip`
   bus, no BRAM section). Work-RAM memory test now passes.
4. **Next stall: C-chip ASIC ready flag.** 68k spins at `0x2AE2` polling
   `cmpi.b #$1, $900803` (or `#$5` for error). Added small HLE in
   `_main.v`: `cchip_hle_byte` returns `0x01` when reading ASIC byte
   `$903`. Passed.
5. **Next stall: C-chip shared-RAM "GWK" signature** at bytes
   `$001/$003/$005` (= 0x47/0x57/0x4B). Extended `cchip_hle_byte` to
   return those values. Passed.
6. **Next stall: TC0140SYT status poll** at `0x2D6E` — 68k writes index
   4, reads master_comm twice, checks status bit 2 (master-rx-has-data).
   Sound CPU stub doesn't respond, so bit 2 never sets. Added HLE in
   `_syt.v`: when master writes idx 3 (completing a write), force
   status[2]/[3] high and echo slave_data → master_data. Also fixed the
   idx-4 status read to `status_reg | 4'b0100` so first poll succeeds.
7. **Realised the C-chip MCU is uPD78C11 (NEC), not HD6305 (M).**
   jtcores has `jt6805` (M6805 family); **no uPD78xx core exists**.
   Writing one from scratch is weeks of work. Pivoted away from real
   C-chip and toward the real sound CPU + side improvements.
8. **Built real `jtsuperman_snd.v`**: Z80 (`jtframe_sysz80` @ 4 MHz with
   8 KB internal RAM via `RAM_AW=13`), YM2610 (`jt10` @ 8 MHz), full
   wiring to SYT slave-side. Cen generation in `_game.v` via
   `jtframe_cen48`. Sound bus driven by `mem.yaml`'s `snd` (Z80 ROM)
   and `adpcma` (ADPCM-A samples). Boots, lints; remaining warning is
   in `jt10.v` itself (adpcma_bank width — upstream).
9. **Verified palette path.** Wired `pal_addr_b/pal_dout_b` from main →
   game, drove `red/green/blue` from `pal_dout_b[14:0]` (xRGB-555).
   Made it a "palette viewer": address scans all 2048 entries across
   the screen so any non-zero entry shows. Result is all-black because
   Superman clears the first 1 KB of palette at `0x3F60` and never
   writes anything else before stalling on the C-chip. **The palette
   pipeline is working — the palette is just empty.**
10. **Attempted vtimer 60Hz fix → reverted.** Tried 416×240 (99840
    dots @ 6 MHz pxl_cen = 60.1 Hz). The faster vsync cadence put the
    68k into a 14M-ROM-fetch livelock around `0x081A` (couldn't reach
    end of FRAMES=20 in 11+ minutes). Reverted to the working
    456×264 = 49.84 Hz. The fundamental cadence mismatch is on the to-do
    for when real X1-001A timing drives the vtimer.
11. ~~Drafted `jtsuperman_colmix2.v` as a clean Superman-shape colour
    mixer.~~ **Deleted** — the original `jtsuperman_colmix.v` ended up
    handling the live build, the `_colmix2.v` draft never got wired and
    was removed during the May-20 dead-code cleanup.
12. **Built `ver/superman/`** verification tree — `traces/`,
    `mame_scripts/`, `sim_logs/`, `disasm/`, `baseline_frame.jpg`,
    `README.md`. All MAME and JT-sim artefacts captured during the
    iteration loop are preserved there for the next session.
13. **First behavioural C-chip HLE attempt → reverted.** Tried clearing
    `$F01CCE` on every LVBL falling edge via port-B of the work-RAM
    BRAM. Result was worse than nothing: the 68k's memory-test routine
    writes patterns `0x00`, `0xFF`, ... to all of work RAM and verifies
    them — our HLE clobbering `$F01CCE` with `0x0000` on every vblank
    corrupted the `0xFF` pass, sent the 68k into its memory-test-failure
    display routine at `0x1CC0+`, and a 200-frame sim showed it still
    spinning there. Reverted to port-B unused. The lesson: any C-chip
    HLE must be **gated by game phase** (e.g. wait until the memory
    test completes before any side-channel writes). The real C-chip's
    MCU honours timing it observes via its own port lines; we can't
    fake that without modelling more behaviour. Outcomes preserved in
    `ver/superman/sim_logs/with_vblank_hle*.log` for reference.

### What's still in `_main.v` and `_syt.v` that's "fake" (must be removed)

- `cchip_hle_byte` in `jtsuperman_main.v` — returns the magic signature
  + ready flag. Drop when real `jtsuperman_cchip.v` lands.
- HLE echo in `jtsuperman_syt.v` (write idx 3 forces master_data echo +
  status bits) — drop once the real Z80 + sound code in `b61_10` proves
  to provide responses in the same time window.
- IRQ 6 from V-blank in `jtsuperman_main.v` — the real C-chip generates
  IRQ 6 from its INT timer pin. V-blank substitute fires at roughly the
  right cadence but is not authoritative.

### Verified end-to-end facts

- ROM loads correctly into SDRAM bank 0 (verified by direct hex dump of
  `sdram_bank0.bin` at offsets 0x000 and 0x100 matching MAME's view).
- 68k reset vectors: SSP=0x00003FFE, PC=0x00003EF0 — **match MAME**.
- First 16 instructions after reset: traced JT side and MAME side, all
  bytes match exactly. The memory-test pattern and the C-chip-poll
  pattern both confirmed against MAME disassembly.
- Z80 sound CPU elaborates, claims its 8 KB SRAM in `jtframe_sysz80`,
  has access to `jt10` and the SYT slave side.
- Frame production is stable: 30 frames produced per run, JPEG +
  MP4 output via `sim-core.sh` works.

## 2026-05-18 (afternoon): C-chip integration milestone

The C-chip is now functional. Commits in this order:

1. `290ca52bc` initial bring-up (kiwi scaffold)
2. `92ce95118` C-chip disassembly artefacts
3. `ea8adf330` integrate Fulvio's real uPD78C11 (replaces HLE)
4. `5aec3684c` MCU activity probe
5. `d3aa1538c` STATUS.md update
6. `af625270b` vblank pulse → C-chip INTF1 + richer MCU probe
7. `b8207fac0` align wrapper ASIC/bank map with MAME — **boots past GWK**
8. `9cc81d845` IRQ-6 ack diagnostic + boot-state finding

### What now works end-to-end

- **Real uPD78C11 firmware (Fulvio's CPU core) executing** — both
  Taito's shared 4 KB mask ROM (CRC `0x43021521`, SHA1 `73bc4b46…`
  matching MAME's `cchip_upd78c11.bin` exactly) and Superman's 8 KB
  EPROM (b61_11.m11). Mask ROM is **NOT a guess** — it's the dumped
  silicon byte-for-byte.
- **Vblank-driven INTF1.** game.v generates a 1-clk pulse on the
  falling edge of LVBL and feeds it to the wrapper's `ext_tick`,
  which becomes the MCU's INTF1 — matches MAME taito_x.cpp:

      m_maincpu->set_input_line(6, HOLD_LINE);     // 68k IRQ-6
      m_cchip->ext_interrupt(ASSERT_LINE);          // MCU INTF1

- **Wrapper memory map matches MAME taitocchip.cpp** (now imported as
  `cores/superman/doc/taitocchip.{cpp,h}` for offline reference):
  - MCU ASIC region 0x1400-0x17FF (was wrongly clamped to 0x1400-0x1403)
  - 68k-side bank reg at `$900C01` (ASIC word offset 0x200) — Superman
    absolutely uses this; clears banks 2, 1, 0 in turn during boot
  - Bank-set writes no longer also clobber the 4-byte asic_ram mirror

### Behavioural progress

With FRAMES=80 sim:

- MCU PC reaches **0x21d3** (past the GWK signature write at 0x21AF-0x21BB)
- C-chip handshake completes: the 68k writes `J,F,4` (0x4A/0x46/0x34) to
  `$900001/3/5`, MCU recognises the pattern, writes back `G,W,K`
- 68k unblocks from the wait at `$2C26` and runs the full hardware
  self-test sequence
- All five tests (ROM checksum, work RAM, sprite RAM, palette RAM,
  sound) report PASS — boot displays the **"NO ERROR"** result screen
  via the sprite-text renderer at `$1820`

### Current halt: PC $1852 — "self-test passed, halted"

After the self-test, the 68k reaches `JMP.L $002E6A` at `$3EEA`, which:

1. `ORI #$0700, SR` — raises SR.I=7 (masks IRQ-6)
2. Clears palette to $FFFF + 16 KB of sprite RAM at `$E00000`
3. Selects sprite-table 0 ("NO ERROR" string at `$2F3E`)
4. `BRA $1820` — sprite-text render loop walks the string
5. `BEQ $1852` on the 0-terminator → `BRA $-2` infinite halt with SR.I=7

Result: 30 IRQ-6's were taken during init (SR.I=4), then none after the
68k enters the halt with SR.I=7.

The other result strings in the same table — `WORK RAM ERROR`,
`OBJECT RAM ERROR`, `COLOR RAM ERROR`, `SOUND ERROR` — confirm this is
the post-self-test result-display path. We're sitting in the "all
tests passed" terminal state.

### Open question for the next session

The screen-render path is gated by `CMPI.W #2, ($1CCA, A5)` at `$3ED0`
— if `work_ram[$F01CCA] == 2`, the boot RTS's instead of jumping to
`$2E6A`. But the 5 places in ROM that write to `($1CCA, A5)` store
the values `0, 1, 3, 4` — **never 2**. So the gate is never satisfied
and the screen always renders.

Three hypotheses to test:

1. **The boot is supposed to JSR (not JMP) into the renderer**, return
   via RTE, and continue. The render loop's `BRA -2` would then be
   interrupted by IRQ-6 (timer-driven). Requires SR.I < 6 during the
   render, which conflicts with the `ORI #$0700, SR` at `$2E6A`.
   Maybe Superman's real `$2E6A` lowers SR.I again before the BRA;
   our copy doesn't. Compare against MAME's output to see if the same
   instructions execute.

2. **A C-chip side-channel sets `$F01CCA` to 2** via shared-RAM write,
   on a code path we haven't traced.  The cchip's EPROM at 0x21BB+
   (immediately after the GWK write) might write `2` into shared RAM
   at an offset that maps onto `$F01CCA` once the 68k has copied the
   shared-RAM window out.

3. **`$F01CCA` value 2 means "in service-mode test loop"** and is
   normally never written — and the result-screen at $1852 is the
   normal end-of-self-test idle state.  Real arcade operators see
   "NO ERROR" briefly because something *else* (e.g. coin insert →
   IPL=7 NMI?) eventually advances the boot.  Our IRQ-7 vector is
   `$FFFFFFFF` so NMI isn't set up — could be a clue.

### Next concrete steps

1. Side-by-side compare: stream MAME's superman 68k disassembly into
   our trace tooling and find where MAME's boot diverges from ours
   between PC `$3E50` and `$3EEA`.
2. Probe `$F01CCA` in sim — log every write and read, including the
   address-bus byte values, so we see exactly what the boot was doing
   with the flag.
3. Once boot continues past `$1852`, the next gating issue will almost
   certainly be the X1-001A video subsystem (sprite render to
   `$D00000`/`$E00000` is just hitting BRAM, not the real sprite
   engine).

## 2026-05-18 evening: BOOT COMPLETE — game running attract mode

The boot is now in attract mode.  Final commit of this thread is
b5fc1e757 (ADC fix).

### How we got here

Probing the 6 callers of `$2E6A` (the error-screen dispatcher)
revealed the boot was hitting `$3B34` — which sets D7=$30
("TILT") and jumps unless `$F01CCA == 2` OR bit 3 of `$F01C50`
is set. `$F01C50` is built by the IRQ-6 ISR from cchip ADC reads.

MAME's `taito_x.cpp` wires each bit of IN2 to a separate ADC
channel (an0..an7), each returning $FF if the bit is set, else 0:

    an0 = IN2 bit 0 (COIN1)
    an1 = IN2 bit 1 (COIN2)
    an2 = IN2 bit 2 (SERVICE1)
    ...
    an7 = IN2 bit 7 (TILT)

Our wrapper only exposed cr0..cr3.  We had `cr0=cab_in2` (whole
byte) and `cr1=cr2=cr3=0`.  Because `cr3` was zero, the MCU read
AN7 as "TILT active" → boot halted on the TILT screen at $1852.

### The fix

Fanout cab_in2 bits into the 4 visible cr inputs:

    .port_cr0 ( {8{cab_in2[0]}} )   // AN0 = COIN1
    .port_cr1 ( {8{cab_in2[1]}} )   // AN1 = COIN2
    .port_cr2 ( {8{cab_in2[2]}} )   // AN2 = SERVICE1
    .port_cr3 ( {8{cab_in2[7]}} )   // AN7 = TILT  ← the critical one

(Proper fix is to model the 8-channel scan inside the uPD78C11
core — CR0..CR3 should multiplex AN0..AN3 vs AN4..AN7 driven by
the ANM register.  Punted.)

### Result (FRAMES=80)

   final 68k PC : $0818 (BRA -2 — proper post-init idle wait
                  in the `BSR game_step; BRA -2` pattern)
   final intn   : 1 (no pending IRQ — clean idle)
   IRQ-6 acks   : 210+  (vblank ISR servicing nominally)
   CALLER events: 0  (no error path triggered)

Per-region writes per 250K ROM fetches in the active phase:
   palette : +4800 writes (color animation)
   VRAM    : +73K writes  (tilemap rendering)
   OBJ RAM : +137K writes (sprite engine working)
   SYT     : +771 writes  (sound commands)
   C-chip  : +909 access  (per-frame input polling)

Frames produced: 6 distinct JPEGs (the simulator emits a frame
only when the screen changes).  The palette viewer shows the
palette evolving from black to fully painted with the Superman
title palette — cyan, white, gray, red, green, blue/gold
gradients.  Game is alive.

### What's still missing

- ~~**X1-001A video engine** isn't wired yet.~~ **DONE.** Two
  `jtsuperman_obj` instances directly in `game.v` (FG + BG), pixel-
  perfect against all 17 MAME burst captures. The kiwi-derived
  wrapper (`_video.v / _gfx.v / _tilemap.v`) that was originally
  copied over has been deleted as dead code.
- **Sound is silent** but the path is mostly alive.  Z80 boots,
  programs YM2610 (200+ register writes at boot, FM channels set
  to TL=$7F = silent mute), then sits in an idle loop doing
  periodic Timer-A counter refreshes.  68k SYT activity (probed at
  FRAMES=160 ≈ 3.2s after boot completes): only soft-reset toggles
  via `idx 4 + $FF/$00` — never any actual sound command via
  idx 0..3 data writes.  Boot likely hasn't reached the attract-
  music phase yet (try FRAMES=500+ next time, or simulate a coin
  insert via `cab_in2[0]`).
- **8-channel ADC scan** in the MCU core (cosmetic — current
  fanout handles all the Superman-relevant bits).

