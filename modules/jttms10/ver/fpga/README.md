# DataStorm TEI0022 regression runner

Work for [jtcores #145](http://gitea.jotego.es/jotego/jtcores/issues/145).

## Version 3 FPGA validation

The current RTL and SSH transport use protocol version 3. It adds external
stores, independently frozen primary/following register observations, WVP and
the original bench's positive and posted-write drain boundaries. Synchronous
RAMs and FPGA-side target timing remain in use. The fixture definitions and
Python expectations are unchanged. HOLD, external interrupt scheduling and
EMU RUN-low scheduling still require separate extensions.

Version 3 has matched the original Verilator bench for 29 physical observations,
including unaligned/high-address stores, dependent following instructions,
register-list stores, FILL and LINE: 17 base cases and six each at W1/P7-after0
and W3. A separate intentionally failing diagnostic matches the original
memory snapshot and errors when its final boundary coincides with a write ACK.
Physical timeout, 512-record overflow and malformed-descriptor probes fail,
while subsequent independent cases and clean rearm pass.
An additional timeout interrupts an active write during the posted drain;
the next register-list/following case reinitializes overlapping memory and
passes, as does a clean rearmed batch.

The complete matrix passes all 141,236 fixtures across 127 forms in each of
base, W1/P7-after0 and W3: 423,708 FPGA executions on one configuration.
All 5,151 batches per profile pass. Every raw result was replayed with the
original Python oracle; the largest case needs 231 of 512 event records.
Full external host wall is 284.86/296.71/299.87 seconds respectively, exit 0,
including transfer, execution, checking and report generation. These are
observed runs, not a controlled comparison of the profile time differences.
This validates current fixture contracts: six PIXBLT forms have no timing
probes and 448 MOVB source/target cases remain unresolved. It is not full
#144 acceptance.

The image SHA-256 is
`0cdfad2e3f943514cf7d0196962dc915d6363e8f7284f27777fb1b8ba258e9a8`;
runner RTL SHA-256 is
`fe9b22038a06ec17610d9763052605538f1a8733cd1c65d5a6d3a3d8624e7ee7`.
The retained-IP Quartus flow took 820.91 seconds (823.82 s outer helper),
with all 35 source and 171 packaged inputs unchanged. All eight runner RAMs
and both CPU RF mirrors infer `altsyncram`. The appliance fits in 7,284 ALMs
and 348/397 RAM blocks. All four analyzed timing corners have positive slack
and zero negative TNS; runner setup is at least +5.019 ns. This includes the
test infrastructure and is not CPU-only area or final NARC/MiSTer board closure.

| Profile | Full host wall (s) | Batch transfer (s) | FPGA staging (s) | FPGA run (s) | FPGA result drain (s) | Python checking (s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Base | 284.86 | 10.487 | 11.684 | 52.732 | 113.274 | 51.954 |
| W1/P7-after0 | 296.71 | 13.196 | 11.747 | 58.907 | 113.398 | 52.252 |
| W3 | 299.87 | 10.913 | 11.706 | 69.908 | 111.930 | 51.803 |

The target phases nest inside the SSH execution time; do not add them twice.
Full wall includes final serialization/stdout/cleanup omitted from the driver's
internal timer. A short local verification briefly overlapped the start of W3;
these wall measurements do not isolate the cost of each stimulus setting.

The complete 2,240-case base FILL subset also matches the original Verilator
bench exactly through the copied DataStorm skill driver. Its FPGA command
took 9.39 seconds; preparing its manifest took another 8.187 seconds. The
ordinary Verilator command took 26.571 seconds including generation, model
compilation, simulation, checking and reporting. Thus the observed loaded-image
workflow was 17.577 versus 26.571 seconds, about 1.51 times faster including
manifest preparation. This is one matched pair, not a full-matrix software
comparison. The initial FPGA build above and 1.16-second programming SSH command
(0.340538 seconds on the target, image already staged) are separate upfront
costs. It does not establish a fresh-image or changed-RTL iteration speedup.

Preparation and RTL smoke checks default to version 3. The source checker
retains archived V1/V2 captures; the current transport rejects older wire
layouts. Pin the protocol explicitly in reproduction commands:

```sh
python3 modules/jttms10/ver/fpga/check_results.py prepare \
    --protocol-version 3 --matrix --output /path/to/v3-manifest.json
```

To expose the 45 known agreeing TI MOVB duration targets, use
`prepare --protocol-version 3 --published-targets --output /path/to/targets.json`
instead. These fixtures deliberately select the printed duration while
preserving programs and every other check; they fail the baseline CPU and
must return a nonzero host command. See [source-policy.md](../../docs/source-policy.md).
The ordinary passing 141,236-case matrix does not establish those targets.

The driver supports up to 8,192 batches, streams returned captures to host
storage and preserves partial
output if its configurable transport timeout expires. Consult the version 3
section of [PROTOCOL.md](PROTOCOL.md) for the exact descriptor/result contract.

## Physical version 2 checkpoint (2026-10-19)

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

## Source-bound runs and ROM-only updates

Current `run_batch.py` requires a receipt binding the CPU implementation and
its generators to the compiled image. Refresh historical receipts lacking
CPU fingerprints into a new file with `write_programming_receipt.py`, using
the original fitted build and matching checkout; preserve published receipts.
Fixture programs and the independent Python oracle are excluded from this
implementation fingerprint. They can change without recompiling the FPGA.
The same receipt can be used from another checkout with identical inputs.

For changes to `ucode/tms10.yaml` that regenerate only `tms10.uc` among the
synthesized artifacts, reuse the fitted database with this limited update:

```sh
fpga_baseline=/path/to/baseline-checkout
fpga_variant=/path/to/changed-cpu-checkout
bash modules/jttms10/ver/fpga/build-rom-update.sh \
    --base-build /path/to/original-fitted-build \
    --source-root "$fpga_baseline" --hardware-source-root "$fpga_variant" \
    --parent-receipt /path/to/source-bound-baseline-receipt.json \
    --build-dir /path/to/new-fit-clone --evidence-dir /path/to/new-evidence \
    --variant my-rom-change --overlay my-unique-overlay \
    --boot-id "$fpga_boot_id"
```

Set `fpga_boot_id` from `/proc/sys/kernel/random/boot_id` on the board. The new build directory must not exist; build/evidence paths must be
separate from the immutable base. The helper does not program the board.
It regenerates the variant, rejects source/template/geometry changes outside
this contract, verifies the fitted main-control MIF against the baseline ROM,
then updates its complete 4096-by-62-bit contents and all three source-ROM
copies. It runs `/opt/quartus_free/quartus_cdb --update_mif` followed by
`quartus_asm --read_settings_files=off --write_settings_files=off`. Default
assembly after CDB failed with error 132003 in this project; retain these flags.

The output receipt declares an inherited fit, not a new compilation or STA.
Ordinary RTL/interface/geometry changes use the full compilation flows above.
Keep the original fitted database, parent receipt and evidence files: runtime
validation needs them. The helper hashes the unchanged fitted-file set and
checks that the only changed generated ROM is the declared main-control ROM.
It imports the adjacent receipt writer so a copy in the DataStorm skill can
operate against an explicitly selected baseline checkout.

Program the uniquely named output RBF with a matching, uniquely named overlay
using the proven explicit-close loader and programming procedure above.
These variants inherit SYSID 22 and the parent's timestamp; those values alone
do not distinguish ROM contents. After verifying image hash, overlay, boot ID,
bridges and SYSID, execute with baseline expectations and variant source:

```sh
python3 modules/jttms10/ver/fpga/run_batch.py /path/to/manifest.json \
    --source-root "$fpga_baseline" --hardware-source-root "$fpga_variant" \
    --receipt /path/to/new-evidence/rom-update-receipt.json \
    --parent-receipt /path/to/source-bound-baseline-receipt.json \
    --artifacts /path/to/results --run-name my-rom-change
python3 -m unittest discover -s modules/jttms10/ver/fpga -p 'test_*.py'
```

The source-bound driver rejects a baseline receipt paired with changed CPU
source, and requires explicit parent/source/image evidence for a ROM variant.
It retains the original oracle and fixture expectations. After negative tests,
restore the original image/overlay and run baseline controls.

Physical checks demonstrate both functional and timing regression detection.
Changing ADDK add to subtract at ROM word 0xc1 makes the selected case return
A0=ffffffff instead of 00000001 and wrong ST at the correct 8 INCLK; NOP and ADD
controls pass. A four-microinstruction NOP at words 0x20..0x23 preserves state
but takes 12 instead of 8 INCLK; ADD passes. Both host commands exit 1. All five
mutant/control observations and expected errors match short original Verilator
runs. Eight baseline executions before/between/after the mutants pass and match
Verilator. The final board state is the restored baseline `datastorm-runtime`.
Evidence is under `/nobackup/tasks/jtcores-145/artifacts/v3-rom-update/`.

The reusable helper reproduced exactly the physical functional-mutant RBF in
61.77 seconds external wall, including generation, fit cloning, CDB, assembly
and receipt checks. Generation/clone/CDB/assembly were 2.03/0.16/27.79/28.38
seconds. It preserved 2,577 fitted-file hashes. Original physical variant host
commands took 6.37/6.39 seconds. These are distinct measurement scopes: the
helper excludes programming and test execution, and the earlier 771.34-second
full fit is not a matched recompilation benchmark. A software speedup and
ordinary changed-RTL Rapid Recompile benefit remain unmeasured.

The copied DataStorm skill driver, using the new source-bound baseline receipt,
also passed all 51,542 supported base cases in 1,665 batches after both mutant
restores, with exit 0 and no reprogramming. Full external host wall was 112.05
seconds; the driver sampled 74.963 seconds before report serialization/stdout
and cleanup. Keep these measurement scopes separate. Evidence is in
`v3-rom-update/skill-bundle-full-matrix/`.
