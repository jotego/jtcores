#!/usr/bin/env python3
"""Build the full Superman timing image and its A10/A5 byte-lane ROMs."""
from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
CPU_BYTES = 0x40000
LANE_BYTES = CPU_BYTES // 2
PICO_START, PICO_END = 0x1B800, 0x1C000
STEADY = 1  # exported frames per case; PCB spread was 0-1 loop over 8 frames
LOW_LIMIT = 0x20000  # CPU bytes served by the lower 64 KiB of each lane
SUITE_DESCRIPTION = (
    "taitox-p0-039a-timing-v3-low64k-1frame|pico-window-a10-0dc00|rom-data-010000|baseline|rom-read-1,2,4|"
    "ram-read-1,2,4|ram-write-1,2,4|object-tail-e03ffe-read-1,2,4|"
    "object-tail-e03ffe-write-1,2,4|y-d003fe-read-1,2,4|y-d003fe-write-1,2,4|"
    "object-source-hidden-e003fe-read-1,2,4|write-1,2,4|"
    "object-active-hidden-e023fe-read-1,2,4|write-1,2,4|"
    "baseline-repeat|transition-slot-discard|1-steady-sample|"
    "fixed-dbra-0,128,256,512x3|irq-vectors-2,4,6|ack-600000,300000|"
    "watchdog-400000|marker11-before-irq-enable|clear-stale-latches|isr-ipl7-nesting-mask|"
    "x1-001-demo-screen-two-row-codes1-32-blue-status"
).encode("ascii")


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


with tempfile.TemporaryDirectory(prefix="taitox-timing-") as temp:
    temp = Path(temp)
    asm_obj, c_obj = temp / "timing_diag.o", temp / "timing_firmware.o"
    elf, raw = temp / "timing.elf", temp / "timing.bin"
    run("m68k-linux-gnu-as", "-m68000", "-g", "-o", str(asm_obj),
        str(HERE / "timing_diag.s"))
    run("m68k-linux-gnu-gcc", "-m68000", "-Os", "-ffreestanding",
        "-fno-builtin", "-fno-pic", "-fno-stack-protector",
        "-fno-asynchronous-unwind-tables", "-fno-unwind-tables",
        "-fno-store-merging", "-c",
        "-o", str(c_obj), str(HERE / "timing_firmware.c"))
    run("m68k-linux-gnu-ld", "-T", str(HERE / "timing_layout.ld"), "-o",
        str(elf), str(asm_obj), str(c_obj))
    run("m68k-linux-gnu-objcopy", "-O", "binary", str(elf), str(raw))
    symbols = {}
    for line in subprocess.check_output(["m68k-linux-gnu-nm", "-n", str(elf)], text=True).splitlines():
        fields = line.split()
        if len(fields) == 3:
            symbols[fields[2]] = int(fields[0], 16)

    code = raw.read_bytes()
    suite_offset = symbols["timing_suite_crc32"]
    image_offset = symbols["timing_image_crc32"]
    if len(code) >= PICO_START:
        raise SystemExit(f"assembled image is {len(code)} bytes; must fit below PicoROM window")
    if len(code) > CPU_BYTES:
        raise SystemExit(f"assembled image is {len(code)} bytes; exceeds 256 KiB CPU window")
    if code[suite_offset:suite_offset + 4] != bytes(4) or code[image_offset:image_offset + 4] != bytes(4):
        raise SystemExit("identity fields are not zero placeholders")
    kernel_names = ["timing_baseline", "timing_read1", "timing_read2",
                    "timing_read4", "timing_write1", "timing_write2",
                    "timing_write4"]
    kernel_addresses = [symbols[name] for name in kernel_names]
    if any(b - a != 12 for a, b in zip(kernel_addresses, kernel_addresses[1:])):
        raise SystemExit(f"matched kernels are not contiguous 12-byte blocks: {kernel_addresses}")
    sample_start = symbols["timing_samples"]
    sample_end = sample_start + 35 * (STEADY + 1) * 4
    if not (0x00f00000 <= sample_start < sample_end <= 0x00f04000):
        raise SystemExit(f"sample array is outside Taito X work RAM: {sample_start:#x}-{sample_end:#x}")

    cpu = bytearray(b"\xff" * CPU_BYTES)
    cpu[:len(code)] = code
    cpu[suite_offset:suite_offset + 4] = (zlib.crc32(SUITE_DESCRIPTION) & 0xffffffff).to_bytes(4, "big")
    cpu[PICO_START:PICO_END] = b"\xff" * (PICO_END - PICO_START)
    # Image CRC is calculated with its own field zero, after suite identity and
    # the complete reserved A10/A5 communication window have been installed.
    cpu[image_offset:image_offset + 4] = (zlib.crc32(cpu) & 0xffffffff).to_bytes(4, "big")
    image_crc32 = int.from_bytes(cpu[image_offset:image_offset + 4], "big")
    image_for_check = bytearray(cpu)
    image_for_check[image_offset:image_offset + 4] = bytes(4)
    if zlib.crc32(image_for_check) & 0xffffffff != image_crc32:
        raise SystemExit("image CRC32 self-check failed")
    if cpu[PICO_START:PICO_END] != b"\xff" * (PICO_END - PICO_START):
        raise SystemExit("CPU PicoROM communication window was not reserved")
    high, low = bytes(cpu[0::2]), bytes(cpu[1::2])
    assert len(high) == len(low) == LANE_BYTES
    assert high[0x0dc00:0x0e000] == b"\xff" * 0x400
    if cpu[LOW_LIMIT:] != b"\xff" * (CPU_BYTES - LOW_LIMIT):
        raise SystemExit("image places data above the lower 64 KiB of each lane")

    fixed_brackets = []
    pair = 0
    for count in (0, 128, 256, 512):
        for repetition in range(3):
            start_code = 0x020 + pair * 2
            end_code = start_code + 1
            fixed_brackets.append({
                "count": count,
                "repetition": repetition,
                "start_cpu_read": f"0x{0x01bc00 + start_code * 2:06x}",
                "end_cpu_read": f"0x{0x01bc00 + end_code * 2:06x}",
                "start_event_low9": f"0x{start_code:03x}",
                "end_event_low9": f"0x{end_code:03x}",
            })
            pair += 1

    outputs = {
        "timing_cpu.bin": bytes(cpu),
        "timing_a10_even_high.bin": high,
        "timing_a5_odd_low.bin": low,
    }
    for name, data in outputs.items():
        (HERE / name).write_bytes(data)
    with (HERE / "timing_diag.lst").open("w") as listing:
        subprocess.run(["m68k-linux-gnu-objdump", "-d", "-S", str(elf)],
                       check=True, stdout=listing)
    import re
    upper = re.findall(r"(?<![0-9a-fx])0x0*[23][0-9a-f]{4}(?![0-9a-f])", (HERE / "timing_diag.lst").read_text())
    if upper:
        raise SystemExit(f"listing references CPU addresses above 0x01ffff: {sorted(set(upper))}")
    odd = [line.strip() for line in (HERE / "timing_diag.lst").read_text().splitlines()
           if re.search(r"\s(move[wl]|clr[wl]|tst[wl]|add[qi]?[wl]|sub[qi]?[wl]|cmp[iw]?[wl]|ori?[wl]|andi?[wl]|eori?[wl])\b.*%(sp|fp|a[0-6])@\(-?\d*[13579](,|\))", line)]
    if odd:
        raise SystemExit("possible odd-address word/long accesses:\n" + "\n".join(odd))

    primary_order = [
        "baseline", "rom-read-1", "rom-read-2", "rom-read-4",
        "ram-read-1", "ram-read-2", "ram-read-4",
        "ram-write-1", "ram-write-2", "ram-write-4",
        "object-tail-read-1", "object-tail-read-2", "object-tail-read-4",
        "object-tail-write-1", "object-tail-write-2", "object-tail-write-4",
        "y-read-1", "y-read-2", "y-read-4",
        "y-write-1", "y-write-2", "y-write-4",
    ]
    supplemental_order = [
        f"object-source-hidden-code-{direction}-{count}"
        for direction in ("read", "write") for count in (1, 2, 4)
    ] + [
        f"object-active-hidden-code-{direction}-{count}"
        for direction in ("read", "write") for count in (1, 2, 4)
    ]
    manifest = {
        "board": "Taito X P0-039A Superman",
        "purpose": "matched frame-paced memory timing diagnostic",
        "firmware_build_id": "0x2303",
        "suite_id": "taitox-p0-039a-timing-v3-low64k-1frame",
        "suite_crc32": f"{zlib.crc32(SUITE_DESCRIPTION) & 0xffffffff:08x}",
        "image_crc32": f"{image_crc32:08x}",
        "source_files": ["timing_diag.s", "timing_firmware.c", "timing_layout.ld"],
        "assembled_bytes": len(code),
        "cpu_image_bytes": CPU_BYTES,
        "lane_image_bytes": LANE_BYTES,
        "run_order": primary_order + supplemental_order + ["baseline-repeat"],
        "primary_case_count": len(primary_order),
        "supplemental_case_count": len(supplemental_order),
        "steady_samples_per_run": STEADY,
        "sample_storage_cpu_address": f"0x{sample_start:08x}",
        "kernel_addresses": {name: f"0x{address:06x}" for name, address in zip(kernel_names, kernel_addresses)},
        "transition_sample": "slot 0 is retained internally and excluded from the exported sample; its handler path matches steady samples",
        "sample_format": "big-endian uint32 loop counts, four per data frame",
        "result_frames": f"metadata flags 0x01, range/CRC flags 0x02, IRQ2/4/6 counters flags 0x04, {(35 * STEADY + 3) // 4} data flags 0x10, terminal CRC flags 0x20",
        "pico_protocol": "type-2 27-byte frames, CRC16-CCITT, sequence ACK, compact sample CRC32",
        "pico_tx_cpu_window": "0x01b800-0x01bfff",
        "pico_a10_physical_window": "0x00dc00-0x00dfff, FF-filled",
        "picorom_size": "64 KiB per lane (addr_mask 0xffff); CPU 0x000000-0x01ffff only, nothing above is placed or accessed",
        "rom_read_cpu_address": "0x010000",
        "irq_handling": {
            "vectors": {"26": "IRQ2 VBL", "28": "IRQ4 C-chip", "30": "IRQ6 VBL+C-chip"},
            "sample_source": "first observed IRQ2 or IRQ6; IRQ4 is acknowledged and counted but never samples/resets the loop count",
            "acknowledgements": {"IRQ2": "write 0x0010 to 0x600000", "IRQ4": "write 0x3000 to 0x300000", "IRQ6": "write 0x3000 to 0x300000 and 0x0010 to 0x600000"},
            "watchdog": "write 0x0010 to 0x400000 on every IRQ and during the startup wait/result ACK wait",
            "startup": "service watchdog before RAM qualification; service again after each RAM pass; service and clear both pending IRQ latches before marker 0x11 and before enabling IRQs",
            "overhead": "each ISR masks IPL7 before saving registers, then acknowledges/services watchdog before C sampling work; this nonreentrant handler overhead is outside timed kernels but remains in per-frame loop counts",
        },
        "expected_irq_level": 6,
        "fixed_count_mode": {
            "loop": "DBRA with N=0,128,256,512; N=0 skips DBRA",
            "repetitions_per_count": 3,
            "marker_timestamps": "RP2040 event timestamps in microseconds (1 us resolution); bracket duration is not CPU edge/cycle time",
            "event_budget": "28 events total including reset/RAM/start/end markers, within the PicoROM 31-entry ring",
            "capture_order": "snapshot the event ring before requesting framed results; TX events can overwrite ring entries",
            "dbra_note": "N>0 executes N DBRA instructions, costing 10*N + 4 CPU cycles before observer overhead; N=0 skips DBRA",
            "brackets": fixed_brackets,
        },
        "object_test_address_note": "Primary object-tail E03FFE is unused RAM at word offset 0x1fff and outside the MAME EOF sprite-bank copy. Supplemental probes use hidden sprite entry 511 code words at E003FE (source) and E023FE (active), with X/Y set offscreen before timing.",
        "diagnostic_screen": {
            "setup": "boot-v4 X1-001 pattern: mirror source and active LUTs, hidden unused entries, draw game tile codes 1..32 as a two-row color strip on blue backdrop",
            "status_backdrops": {"waiting": "blue 0x001f", "irq2": "green 0x03e0", "irq4-before-vblank": "cyan 0x03ff", "irq6": "red 0x7c00", "suite-complete": "white 0x7fff", "fatal": "magenta 0x7c1f"},
            "setup_timing": "all screen initialization and status writes are outside timed kernels",
        },
        "sha256": {name: sha256(data) for name, data in outputs.items()},
    }
    (HERE / "timing_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))
