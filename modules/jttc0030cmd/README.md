# jttc0030cmd — Taito TC0030CMD "C-Chip"

A jtframe wrapper around the [IKA87AD](https://github.com/ika-musume/IKA87AD)
core (Raki's decap/datasheet-based NEC uCOM-87AD / uPD78C11), implementing the
full Taito C-chip as a single reusable module.

Used by Taito games that carry the C-chip: Superman and the rest of the
taito-x family, Operation Wolf, etc.

## ⚠ License restriction (read before wiring a new game)

The vendored IKA87AD files are under the **"Taito C-Chip Temporary License"**
(`LICENSE.IKA87AD`): BSD-2 **plus clause 3**, which forbids using this code —
even a snippet — to implement Taito's **Rainbow Islands** until the upstream
author ships his own FPGA core for that game.

**Do not connect `jttc0030cmd` to the `rbisland` driver.** Every other C-chip
game is unaffected. Revisit if/when Raki removes the clause upstream.

## Package contents (the real chip, 4 dies)

| Die | Part | Role |
|-----|------|------|
| 1 | uPD78C11 MCU + 4 KB mask ROM | CPU; mask ROM common to all games |
| 2 | uPD27C64 8 KB EPROM | game-specific program |
| 3 | uPD4464 8 KB SRAM | shared with the 68k, banked 1 KB windows |
| 4 | ASIC (NEC ULA) | 4-byte reg file, two bank registers, /DTACK |

## Memory map

MCU internal view (matches `taito_cchip_device::cchip_map`):

| Range | Contents |
|-------|----------|
| `0x0000-0x0FFF` | internal mask ROM (RO) |
| `0x1000-0x13FF` | 1 KB SRAM window, bank = `bank_mcu` |
| `0x1400-0x17FF` | ASIC: write `0x1600` → `bank_mcu`; else 4-byte reg file |
| `0x2000-0x3FFF` | game EPROM (RO) |
| `0xFF00-0xFFFF` | 256 B MCU internal RAM |

Host (68k) external pins `A0-A10`, `D0-D7`, `/CS`, `R/W`, `/DTACK`:

| Range | Contents |
|-------|----------|
| `0x000-0x3FF` | 1 KB SRAM window, bank = `bank_68k` |
| `0x400-0x5FF` | ASIC 4-byte reg file |
| `0x600`       | write `bank_68k` (low 3 bits) |

`bank_mcu` and `bank_68k` are **independent** views into the one 8 KB SRAM
(as MAME keeps `m_upd4464_bank` and `m_upd4464_bank68`).

## Notes

- The C-chip has **no 68k interrupt output** (pin 34 is `/DTACK`); games poll
  the shared RAM. `int1` (vblank) and `nmi_n` are inputs to the MCU.
- `int1` is **edge-triggered and conditioned internally**: assert it (rising
  edge) to request one IRQ. Wire the raw vblank straight in — pulse, short
  level, or a full-vblank level (`~LVBL`) all work; the module holds the request
  across the IKA sample filter and releases on its own, so no per-game pulse
  shaper is needed and a sustained level never re-triggers.
- IKA87AD exposes the full 16-bit address (`o_A`) directly, so the
  MODE0/MODE1/MM external memory remap is not modelled — the wrapper simply
  places storage at the addresses above.
- ADC: each `an[x]` reads back as `0xFF`/`0x00` (MAME's `anN_func`); AN4-7 also
  feed the digital edge detector.
- BRAM runs at full `clk` rate; its 1-cycle latency hides inside the slower
  `cen`-gated MCU cycle, so the read mux is combinational.
- Load the mask ROM via `mrom_we` and the EPROM via `eprom_we` (jtframe
  download), or point `SIMHEX_MROM` / `SIMHEX_EPROM` at hex files for sim.

## Tests

JT-format `simunit` tests live under `ver/` — run one with the simulator image:

```bash
docker run --platform linux/arm64 --rm -v "$(pwd)":/jtcores -w /jtcores \
  jotego/simulator:arm64 \
  -c "source setprj.sh; cd modules/jttc0030cmd/ver/<test> && simunit.sh --run ."
```

| Test | Covers |
|------|--------|
| `lint`    | elaboration + a short smoke run (verilator lint gate) |
| `int1`    | INT1 conditioning: edge-triggered — a pulse, a short level, and a full-vblank-length level each give exactly one ~192-cen-tick hold measured from the rising edge (a long level releases mid-level, not extended); counted in `cen` ticks so it is clock-rate tolerant |
| `hostmem` | 68k-side memory map: shared-SRAM windowing, `bank_68k` independence, the ASIC 4-byte reg file, `/DTACK` |

These cover the **wrapper** (the new code). The **CPU core** is validated
upstream: IKA87AD's own `sim/` runs every instruction/addressing mode and
checks state counts, flags, effective addresses and ALU results against a
datasheet-derived golden (Verilator + C++; not ported here).

## Provenance

`IKA87AD*.sv` are vendored verbatim from https://github.com/ika-musume/IKA87AD
with a license header prepended (clause 1). The wrapper `jttc0030cmd.v` is
original JTCORES (GPL-3) work. MAME's `taitocchip.cpp` is the behavioural
reference for the memory map only.
