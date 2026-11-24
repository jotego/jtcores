# PicoROM-based PCB work

`jtutil picorom` drives [PicoROM](https://github.com/wickerwaka/PicoROM) ROM
emulators plugged into the program ROM sockets of an arcade PCB. It loads and
verifies images, switches the PCB supply, samples ROM pins and runs CPU bus timing
tests that can be compared with the FPGA core in `jtsim`. It is written in Go
(`$JTFRAME/src/jtutil/picorom`) and talks to the units through Linux usbfs, so it
needs neither libusb nor Python. See `man jtutil-picorom` for every option.

## Setup

- **USB access**: a udev rule giving the lab user read/write access to
  `2e8a:000a` (and `2e8a:0003` for the bootloader).
- **Lab file**: `$JOTEGO/picorom.yaml` holds everything specific to the local
  laboratory. It is not part of the repository.

```yaml
units:                    # key: USB chip serial, as printed by "jtutil picorom units"
  E6614103E7123456:
    name: unit1
    pins: 32
    note: POG board, diagnostic firmware (event recorder)
  E6614103E7654321:
    name: unit2
    pins: 32
    disabled: "pin 2 shorted to GND"   # never loaded
power:                    # omit for a manual switch
  type: shelly-gen2       # Shelly Gen2+ local RPC
  url: http://192.0.2.10
  id: shellyplugsg3-0123456789ab       # checked before every switch
  switch: 0
  interface: wlo1         # optional: bind the HTTP requests to one NIC
programmer:
  minipro_device: "AM27C010@DIP32"     # for load --xgecu
```

- **Tools**: `m68k-linux-gnu` binutils for 68000 tests, `minipro` for the XGecu
  check, and the usual `jtsim` environment for simulations.

Units are named in their own flash (`jtutil picorom rename`), so new units only
need a lab entry. Bus tests choose the units at run time: the marker lane goes to
a unit whose firmware has the event recorder (the jtkcpu diagnostic firmware,
`/nobackup/jtmisc/reverse/PicoROM`, branch `jtkcpu-1`), the other lanes to the
remaining usable units. `--unit lane=NAME` overrides that.

## Everyday commands

```sh
jtutil picorom units                    # what is connected, capabilities, lab entry
jtutil picorom power status             # PCB supply (on/off, watts)
jtutil picorom load unit1=even.bin unit2=odd.bin --size 64k
jtutil picorom probe unit1              # power briefly, sample pins
```

Safety rules built into the tool:

- No image is loaded while the PCB is powered (checked through the power switch,
  or confirmed by the operator with a manual switch).
- Only `power on`, `probe` and `bustest run` switch the PCB on, and the last two
  always switch it off when they finish or fail.
- `bustest run` prints the placement and checklist first and waits for a
  confirmation at the terminal, or for `--yes` once the board is ready.
- Every load reads the whole image back and compares it.

Every command accepts `--json`. Exit status: 0 done, 1 error, 3 a PCB run that did
not complete.

## Bus timing tests

A bus test times 256 iterations of a loop with four accesses to one address, three
times per case, between marker reads of the recorder unit's communications window.
The recorder timestamps the markers on the PCB; in `jtsim` a verification-only
harness hook logs the same reads with the simulated time. Without wait states a
68000 loop takes 42 CPU clocks (26 for the baseline); each extra clock on the four
accesses adds 4.

```sh
jtutil picorom bustest show riders           # sets with a test
jtutil picorom bustest show riders glfgreat  # placement, cases, checklist
jtutil picorom bustest gen riders glfgreat   # test.s, lane images, manifest.json
jtutil picorom bustest sim riders glfgreat   # jtsim reference (rom/<set>.rom needed)
jtutil picorom bustest run riders glfgreat   # on the PCB
jtutil picorom bustest report riders glfgreat
```

Files go to `cores/<core>/ver/<set>_bustest/`, a `jtsim` folder for the core that
Git ignores: `test.s`, `*_lane.bin`, `manifest.json`, `sim_result.json`,
`jtsim.log`, and one `pcb_<utc>/` folder per PCB run with the load report and
`pcb_result.json`. Record conclusions in the core README's bus timing section.

### Defining a test

Tests live in `cores/<core>/cfg/picorom.yaml`, one entry per set:

```yaml
bustest:
  glfgreat:
    board: "Golfing Greats GX061"
    cpu: m68k                  # backend
    cpu_hz: 16000000           # CPU clock on the PCB
    rom:
      cpu_base: 0x0            # CPU address of the ROM pair with the reset vector
      even: "1H"               # socket with D15-D8
      odd: "4H"                # socket with D7-D0
      chip: "27C010"
      pins: 32
      comms_lane: even         # socket that serves the markers (default even)
      rom_offset: 16           # program offset inside rom/<set>.rom
      word_swap: true          # .rom stores CPU words byte-swapped
    ram: {base: 0x100000, size: 0x4000}
    watchdog: {addr: 0x124000, access: write.w, why: "schematic reference"}
    init:                      # optional setup writes
      - {addr: 0xa0020, access: write.w, value: 0, why: "..."}
    cases:
      - {name: adc, addr: 0x123000, access: read.w, expect: "1 wait (7F chain)"}
    checklist:                 # printed before power-on
      - "Leave JP3 as found"
    sim:                       # optional jtsim settings
      ms: 60                   # simulated time
      download: 0              # >0: send this many bytes through the simulated download
      defs: []                 # extra -d macros
      rom_patch: []            # [{offset, bytes}] changes to rom.bin (e.g. a decryption flag)
```

Rules:

- The program and every ROM test address stay in the lower 64 KiB of each chip
  (the units load in 64k mode): CPU `cpu_base` to `cpu_base+0x1FFFF` for a 68000.
- Only touch harmless regions: no DMA trigger, sound command or bank switch. Write
  only RAM-like regions.
- Keep the addresses consistent with the core's decoder.
- Check every address line a fitted unit cannot drive or sense. In #230 a unit with
  pin 2 (ROM A16) shorted to ground held CPU A17 low on the whole board: every
  address with A17 set landed elsewhere, and RAM accesses there never got DTACK.
- `expect` and `checklist` are printed by `show`, `run` and `report`. Put longer
  explanations and the measured results in the core README.

When markers stop, `bustest run --stall-probe` (on by default) samples the
recorder's pins before switching off. A constant address with the socket never
selected is a CPU stuck on that cycle (no DTACK); all ones usually means a
tri-stated bus (reset, halt or no clock).

### Simulation hook

`bustest sim` writes `sim_hook.h` in the simulation folder and runs `jtsim` with
`-d SIM_HOOK`. The shared harness (`$JTFRAME/verilator/test.cpp`) then includes the
file and calls `sim_hook(game, simtime)` once per clock period. Other tools can
use the same hook point for verification-only probes.

## Extending

- **Another CPU**: add a file in `picorom/bustest` with a type that implements
  `Backend` (`cpu.go`) and register it in `init()`: lanes (2 for a 16-bit bus in
  byte-wide ROMs, 1 for an 8-bit bus), a `text/template` program like
  `m68k.s.tmpl`, the assembler commands, nominal cycles and the `sim_hook.h`
  template for the CPU model in `jtsim`.
- **Another kind of PicoROM work**: add a package next to `bustest` that uses the
  `picorom` library (units, loading, events, power) and a subcommand in
  `cmd/picorom.go`, with its section in `cfg/picorom.yaml`.
- **Another power switch**: implement `Power` in `picorom/power.go`.
