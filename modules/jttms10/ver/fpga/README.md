# DataStorm TEI0022 regression runner

Work for [jtcores #145](http://gitea.jotego.es/jotego/jtcores/issues/145).

## FPGA batch validation (2026-10-19)

The v2 autonomous runner has executed 154,626 cases on the physical TEI0022:
51,542 supported read-only fixtures each at base timing, W1/P7-after0, and W3.
All 1665 batches per profile passed. Independent raw-capture verification found
no mismatches; the largest individual trace used 141 of 512 records. Full host
command times were 86.28 s, 98.26 s, and 100.75 s, including staging, return
transfer, oracle checking, and report generation. These measurements do not
establish a matched software speedup.

The physical image uses the dedicated no-video test-appliance build: HPS Linux,
Ethernet, and SYSID remain enabled; unused HDMI/DMA logic is removed; the CPU
runner uses a generated 25 MHz PLL output behind Platform Designer's HPS-to-runner
clock crossing, while HPS user1 remains at 100 MHz. The image SHA-256 is
`5c7e6b9a8fc11a6164c12800eaf61eaf31383ad9adc50e88d8b577712c156f2e`; the runner
RTL SHA-256 is
`0a681b94a6b6b0aaa71437975d398508f1294de2f6dbc97ab1ae940e58c709fc`. The
whole appliance uses 6,837 ALMs, 343 of 397 memory blocks, six DSP blocks and
one PLL. All four analyzed timing corners have zero negative TNS; the minimum
setup slack is +1.352 ns on HPS and the runner's worst setup slack is +5.857 ns.
The full Quartus flow took 771.34 s. The programmed SYSID is 22 with timestamp
1792433033, matching the QIP-bound compiled source.

Twenty-one representative fixture executions matched the original timing bench,
including sparse-memory loads, high branch targets, self-jumps, maximum-length
register lists, wraparound stack reads, pixel reads and W1/P7-after0 timing.
Timeout and 512-record trace-overflow negatives returned failure, preserved
their diagnostics, then passed a later independent case and a clean batch
without FPGA reset. A 25,000,000-cycle timeout took 1001 ms on the board's
monotonic clock, consistent with 25 MHz. A separate after7 early-pause negative
records an outstanding request during CEN pause and fails as required by the
original bench; after7 is not an in-flight-response pause mode.

The supported inventory contains 51,542 cases across 93 forms. V2 supports
read-only sparse initialized memory, local memory loads, register-list loads,
pixel reads, control flow, configured target waits, and early CEN pauses.
External writes, following-instruction checks, positive and -2 drain modes,
HOLD, interrupts and EMU RUN-low scheduling remain unsupported and are rejected.
The host checker fails closed on unknown fixture fields. See
[PROTOCOL.md](PROTOCOL.md) for exact fixture boundaries, wire format, commands,
negative tests and immutable evidence paths.

For a changed runner/CPU image, use a preserved generated build as the base and
run one full Quartus flow (no mandatory separate map pass):

```sh
bash modules/jttms10/ver/fpga/build-runner-incremental.sh \
    /path/to/preserved-v2-build \
    /nobackup/tasks/jtcores-145/rebuild-v2 full
```

The helper clones the build database and generated Platform Designer system,
regenerates CPU payload files from the source generators, freezes the recursive
QIP synthesis subtree and other compile inputs, removes any cloned RBF, and
runs `/opt/quartus_free/quartus_sh --flow compile`. It retains logs, timing,
source/input hashes, map/flow certificates, and STA reports. The physical v2-7
image was built from its preserved base in a single full flow. Its original
input snapshot omitted the QIP child files; a separate post-compilation audit
verified all 97 synthesis-subtree files unchanged from the base. The recursive
freeze is a later helper correction; it does not rewrite that build's original
certificate. The earlier v1
image and reports are historical and have narrower coverage; the currently
validated image and evidence are recorded in `PROTOCOL.md` and under
`/nobackup/tasks/jtcores-145/artifacts/v2-7-physical/`.

## Board boot baseline

Use the official Trenz **TEI0022-03 / A5_C8_2GB** reference design for
**Quartus 20.1.1**. This matches the installed `/opt/quartus_free` tools.
The source and prebuilt Linux image are distributed together in
[`TEI0022-test_board-quartus_20.1.1-20220426153922.zip`](https://www.trenz-electronic.de/trenzdownloads/Trenz_Electronic/Development_Boards/TEI0022/Reference_Design/20.1/test_board/TEI0022-test_board-quartus_20.1.1-20220426153922.zip).

The nested archive at
`test_board/prebuilt/A5_C8_2GB/os/yocto/images/tei0022-image-minimal-tei0022-a5-c8-2gb.zip`
contains a complete 357,480,448-byte WIC disk image, including its partition
table. Write the image to the whole microSD device. Its partitions are:

| Partition | Sector start | Sector count | Purpose |
| --- | ---: | ---: | --- |
| 1 | 2048 | 45558 | FAT boot files: FPGA RBF, kernel, DTB, extlinux |
| 2 | 49152 | 2048 | Type A2: raw SPL/U-Boot for the SoC boot ROM |
| 3 | 51200 | 647004 | ext4 Linux root filesystem |

SHA-256 identifiers:

```text
182d6f3017186ddc3e486abf047ca66276462fac67b788367b0c7288838c5d90  vendor ZIP
038649b7a02e982def9e0d79d7146a27b8f3f2be8db0aaa9bbb90a2de5c35891  WIC image
```

With power off, insert the prepared card in **J3** and set **S7-1 ON,
S7-2 OFF** for SD boot. Connect Ethernet and the HPS UART USB connector
**J5**, then power on. The console uses **115200 baud, 8N1**. This specific
stock image uses user **root with an empty password** and DHCP on `eth0`.
It does not include an SSH server; install the development SSH payload offline
or use the serial console for initial access.
The image leaves the remainder of larger cards unallocated.

See the manufacturer's [board manual](https://wiki.trenz-electronic.de/display/PD/TEI0022+TRM)
and [reference-design documentation](https://wiki.trenz-electronic.de/display/PD/TEI0022+Test+Board).
Current online documentation describes newer images, whose login and
filesystem layout differ from this pinned 20.1.1 baseline.

Offline validation checked both archive CRCs, the complete image hash,
the ext4 filesystem with `e2fsck -fn`, boot configuration references,
and console/network configuration. The first physical card write passed a complete image readback comparison.
To use a larger card fully, grow only
partition 3 (keep its start at sector 51200), run `e2fsck` while unmounted,
and expand ext4 with `resize2fs`. Keep both boot partitions unchanged.

The prepared development card has since been expanded to **116.09 GiB**.
Its root partition still starts at sector 51200 and now has 243456000
sectors. Offline filesystem checks passed after expansion.

## Development access

The two micro-USB connectors connect to FTDI UART/JTAG chips: J5 is the
HPS serial console, and J13 selects JTAG targets. They do not expose a
native USB Ethernet gadget connection. The board has no built-in WiFi.
Its other USB ports connect through a host hub; WiFi would require an
adapter with a driver and firmware supported by the installed kernel.
The built-in RJ45 interface already has DHCP configured in the vendor image.

An offline SSH payload is available in the #145 task artifacts. It contains
[Dropbear 2026.94](https://dropbear.nl/mirror/releases/dropbear-2026.94.tar.bz2)
and musl 1.2.5, built as a static ARMv7-A hard-float executable with GCC 10.2.
The multipurpose binary provides the server, host-key generation and SCP.
Password and PAM authentication are disabled at build time; development
access uses this PC's Ed25519 public key. Host private keys are generated
on DataStorm at first boot. A SysV service starts SSH on port 22.

Use `ssh root@BOARD_IP` after DHCP assigns an address. Transfers use
`scp -O FILE root@BOARD_IP:/tmp/`; the payload does not provide an SFTP server.
The serial console remains available independently of the network.

Validation includes static ARM ELF inspection, key generation under QEMU,
a public-key SSH command through the ARM server, a one-MiB transfer into the
ARM SCP receiver with exact data comparison, and rejection of a wrong key
and password authentication. The successful SSH tests used a native
unprivileged account and child shell. Full stock-rootfs login under
proot/QEMU failed at filesystem permission lookups. Physical DataStorm boot,
key-only root SSH and exact SCP upload/readback have since passed on
Linux **5.4.124-altera**. The development board obtained **192.168.68.72** by
DHCP; this address may change. Ethernet negotiated 1 Gbit/s full duplex.
The board exposes approximately 1 GiB HPS RAM and the expanded root filesystem.

## Reproduce the vendor FPGA build

With `setprj.sh` already sourced, pass the pinned ZIP above and a new empty
build directory to the helper. Keep that directory for later compilations:

```sh
bash modules/jttms10/ver/fpga/build-vendor.sh /path/to/TEI0022-test_board-quartus_20.1.1-20220426153922.zip /nobackup/tei0022-build compile
bash modules/jttms10/ver/fpga/build-vendor.sh /path/to/TEI0022-test_board-quartus_20.1.1-20220426153922.zip /nobackup/tei0022-build rapid
```

`prepare` creates only the Quartus project; `generate` also creates the
Platform Designer system. `compile` retains generated IP and the Quartus
database, and `rapid` invokes `quartus_sh --flow recompile`. Every compilation
uses **`/opt/quartus_free`**, including the inherited tool environment.
Platform Designer generation uses the matching 20.1 installation's
`sopc_builder/bin` tools because the wrapper directory has no Qsys launchers.
Commands, logs, elapsed wall time, exit codes and tool version go under
`BUILD_DIR/logs/`. Source ZIP hashes are checked before every action.

The vendor source uses `test_board.bdf` as its top level; the generic board
`top.v` is an empty template. Use the source design's HPS DDR, pinmux and
clock presets. The first build fitted in 2,330 ALMs and 10 RAM blocks.
The fabric's worst reported setup slack was +0.799 ns. Final DDR reports
after calibration have positive margins; negative intermediate paths explicitly
labelled "Before Calibration (Negative slacks are OK)" are not the final DDR
result. The vendor design still reports unconstrained external HPS I/O and
an HDMI PLL constraint warning; this does not establish full board timing closure.

The source design and shipped WIC device tree use different FPGA peripheral
addresses. For example, the rebuilt SYSID is at **0xff210820**, while the
shipped tree describes **0xff201020**. Keep legacy FPGA HDMI/GPIO/DMA drivers
unbound when loading the source build. HPS Ethernet and SD remain available.
The rebuilt image was loaded on the real board and its SYSID **22** and build
timestamp matched the actual compiled `db/ip/.../QSYS_test_board_sysid.v`.
Quartus may regenerate IP during compilation, so use the compiled timestamp,
not the earlier `qsys-generate` timestamp. This prevents bit-identical RBF
reproduction unless that generated timestamp is also pinned.

## Programming through Linux

The vendor kernel supports FPGA programming through configfs device-tree
overlays. A fragment targeting `&base_fpga_region` specifies `firmware-name`
and `fpga-bridges = <&fpga_bridge0>, <&fpga_bridge1>`. Store the RBF in
`/lib/firmware`, unbind FPGA clients, and apply its compiled DTBO with
[fpga-load.c](fpga-load.c). Build it with an ARMv7-A hard-float C compiler;
the development executable is statically linked with musl.

```sh
arm-none-linux-gnueabihf-gcc -O2 -Wall -Wextra -Werror fpga-load.c -o fpga-load
# On DataStorm, after quiescing clients and creating the overlay directory:
./fpga-load image.dtbo /sys/kernel/config/device-tree/overlays/jttms10/dtbo
```

The loader explicitly closes the configfs descriptor while its process is
alive. **Do not use `cat image.dtbo > .../dtbo` on this kernel.** Applying at
process exit triggered a kernel NULL fault in `request_firmware` after the
task's filesystem context had been released. Reboot recovered the board;
explicit close subsequently programmed both the shipped and rebuilt RBFs.
The kernel also warns of property leaks when removing overlays.

The loader's exit status alone is insufficient: check overlay `status` is
`applied`, FPGA manager `state` is `operating`, both bridge states are
`enabled`, and the expected design identifier is readable. Leave clients
unbound on failure. Removing an overlay disables bridges; quiesce clients
before removal as well as before programming. Boot files remain unchanged,
so reboot restores the shipped image.

Initial measurements on this development PC and board:

| Operation | Seconds | Scope |
| --- | ---: | --- |
| Platform Designer system creation | 404.30 | First vendor system |
| Platform Designer HDL generation | 204.78 | First vendor system |
| Full Quartus compile | 440.71 | Four workers; map, fit, assemble, STA |
| Rapid Recompile, no changes | 3.50 | All compilation stages skipped |
| Shipped RBF programming | 0.275 | Target monotonic clock, explicit close |
| Rebuilt RBF programming | 0.281 | Target monotonic clock, explicit close |
| 2 MiB SCP upload | 5.456 | Includes SSH startup |
| 2 MiB SCP download | 2.483 | Includes SSH startup, exact hash match |

These are historical vendor bring-up measurements. The dedicated runner
build and physical regression timings above are separate. Changed-RTL
incremental recompilation benefit and end-to-end speedup against a matched
software matrix remain unmeasured.

## Synthesizable observation interface

Define `JTTMS10_REGRESSION` to expose decode acceptance and accepted PC/IR,
the physical register-file write transaction, selected CPU working state,
pending-field consistency and logical bus start/completion/data through
`jttms10_system`. The macro adds observation outputs; it does not alter CPU
behavior. Normal builds retain their existing port lists.

The register observer reports the existing six-bit physical write address,
including SP aliases and the extended workspace. It adds no RAM read port,
array reset or asynchronous debug mux. The consumer must track which entries
were written in each case; unwritten entries have no defined reset value.
Sample the write transaction and architectural boundary before the edge's
writeback. A snapshot at decode must therefore exclude writes on that same
edge. Bus-start observation requires the timed bus; the raw-bus mode reports
zero on that output.

Check the exposed path with the existing timing fixtures and Python oracle:

```sh
python3 modules/jttms10/ver/fpga/check_observer.py --simulator verilator --case addk
python3 modules/jttms10/ver/fpga/check_observer.py --simulator verilator --case addk --pause-clocks 7
```

The helper derives a temporary bench from `ver/timing/test.sv`. Register
snapshots use a shadow fed only by exposed writes, and decode/bus logs use
the public observer signals. Simulation assertions compare initialized shadow
entries with the real register RAM. Case generation and checking remain in the
existing timing suite. This bench still uses software stimulus and is not the
FPGA batch controller.

Validation so far: strict lint with and without the macro; 192 ADDK cases
with and without a seven-clock CEN pause; and 4,040 mixed MMTM/MMFM/PUSHST,
MOVI and indirect-store cases. The mixed subset's architectural observations,
clock counts, bus traces and target traces exactly match the unmodified bench.
Quartus Analysis & Synthesis on the TEI0022 device with the macro enabled
retains both synchronous 64x32 register RAM mirrors as `altsyncram` and reports
538,624 total block-memory bits. This is an inference check, without a fitted
CPU runner or hardware timing-equivalence claim.
