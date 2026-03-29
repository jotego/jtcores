---
name: edit and understand jtframe mem.yaml files
description: Use this when working on a core cfg/mem.yaml file, including understanding the schema, editing SDRAM or BRAM mappings, clocks, audio, download transforms, and validating jtframe-generated outputs
---

# Scope

Use this skill when the task involves `cores/<core>/cfg/mem.yaml`, generated
memory interfaces, or diagnosing `jtframe mem` and `jtutil sdram` behavior.

`mem.yaml` is not only for SDRAM. It can define:

- `include`, `params`, `ports`, `game`
- `download`
- `clocks`
- `audio`
- `sdram`
- `bram`

# Source of Truth

Prefer the implementation over the docs when they differ.

1. `$JTFRAME/src/jtframe/mem/types.go`
2. `$JTFRAME/src/jtframe/mem/mem.go`
3. `$JTFRAME/src/jtframe/mem/mem_test.go`
4. `$JTFRAME/doc/jtframe-mem.md`
5. `$JTFRAME/doc/sdram.md`
6. Existing core examples in `cores/*/cfg/mem.yaml`

Representative examples:

- `cores/1942/cfg/mem.yaml` for a simple banked SDRAM layout plus BRAM
- `cores/kicker/cfg/mem.yaml` for `params`, `download`, mixed bus widths, and
BRAM `ioctl`

# Workflow

1. Read the target `cfg/mem.yaml`.
2. Read the game module and generated interface expectations before editing.
 Look for `mem_ports.inc`, `/* jtframe mem_ports */`, bus names, BRAM names,
 and any generated `jt<core>_game_sdram.v`.
3. Confirm the supported fields and constraints in the Go parser and tests.
4. Edit `mem.yaml`.
5. Validate the result by sourcing the project environment first:

```bash
source setprj.sh
jtframe mem <core> --target=<target>

Use --local when the task is specifically about local simulation outputs.

6. Inspect the generated outputs to confirm the intended interface:

- jt<core>_game_sdram.v
- mem_ports.inc

Treat generated files as verification artifacts, not as the schema definition.

# What To Check

## General

- include can pull from another core or an explicit file
- params values may reference macros
- ports adds explicit game-module ports
- game overrides the default jt<core>_game module name

## SDRAM

- sdram.banks and sdram.cache-lines are mutually exclusive
- banks must contain between 1 and 4 bank entries
- empty bank entries are valid
- each bank contains buses
- common bus fields: name, addr_width, data_width, rw, offset, cs,
addr, din, gfx_sort, gfx_sort_en, when, unless,
do_not_erase
- data_width is expected to be 8, 16, or 32
- address buses use width-dependent byte indexing:
8-bit starts at bit 0, 16-bit at bit 1, 32-bit at bit 2
- when and unless can remove SDRAM buses depending on macros
- bank layouts map to generated slot modules, so changing slot count or R/W mix
can change the instantiated SDRAM helper module

## SDRAM Cache Lines

When cache-lines is used instead of banks:

- line count must be between 1 and 8
- each line must define cache.blocks
- supported cache data_width values are 8, 16, and 32
- cache size strings must use the exact parser suffixes:
B, k, kB, M, MB
- cache sizes must be exact powers of two
- total cache BRAM must stay below 512 kB
- at.start must be either a parameter name or an explicit hex value like
0x10000
- decimal start values are rejected
- explicit sdram.burst must also parse as a valid size and stay within the
controller limit enforced by the current macros

## BRAM

- BRAM blocks may use addr_width directly or infer it from size
- size uses the same exact suffix rules as cache-line sizes
- do not define both size and addr_width for the same BRAM entry
- BRAM sizes must be powers of two and stay within the parser limits
- common BRAM fields: name, addr_width, data_width, rw, we, addr,
din, dout, sim_file, when, unless
- dual_port can define an auxiliary port with its own name, rw, we,
din, dout, addr
- ioctl controls save and restore generation
- rom.offset uses the download stream as a BRAM ROM source
- prom: true means PROM-style BRAM; PROM data width must be 8 bits or less

## Audio, Clocks, Download

- audio and clock sections are part of mem.yaml; do not treat them as
unrelated config
- audio channel names and module metadata affect generated mixing and debug
behavior
- clock outputs and gating are generated from clocks
- download.pre_addr, post_addr, and post_data change the generated
download interface and may affect jtutil sdram support
- jtutil sdram does not support download address or data transforms

# Practical Guidance

- Reuse existing naming conventions from nearby cores before inventing new bus
names
- If the task is why did jtframe mem fail?, search the error text in
$JTFRAME/src/jtframe/mem
- If the task is what ports should the game module expose?, inspect
mem_ports.inc and the generated game SDRAM wrapper
- If the task is how is this data laid out in simulation?, also inspect
$JTFRAME/src/jtutil/sdram and the jtutil sdram command help
- If docs and code disagree, follow the code and mention the discrepancy

# Commands

Use source setprj.sh before project scripts.

Useful commands:

source setprj.sh
jtframe mem <core> --target=<target>
jtframe mem <core> --target=<target> --local
go test ./modules/jtframe/src/jtframe/mem/...
rg -n "mem.yaml|cache-lines|gfx_sort|ioctl" modules/jtframe/src/jtframe/mem
