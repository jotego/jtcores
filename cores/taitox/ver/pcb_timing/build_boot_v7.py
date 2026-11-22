#!/usr/bin/env python3
"""Build the isolated Superman P0-039A v7 lower-window discriminator."""
from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMAGE_BYTES = 0x40000
LANE_BYTES = IMAGE_BYTES // 2
PICO_WINDOW = range(0x1B800, 0x1C000)


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


with tempfile.TemporaryDirectory(prefix="taitox-boot-v7-") as temp:
    tmp = Path(temp)
    obj, elf, raw = tmp / "boot_v7.o", tmp / "boot_v7.elf", tmp / "boot_v7.raw"
    run("m68k-linux-gnu-as", "-m68000", "-g", "-o", str(obj),
        str(HERE / "boot_control_v7.s"))
    run("m68k-linux-gnu-ld", "-T", str(HERE / "layout.ld"), "-o", str(elf), str(obj))
    run("m68k-linux-gnu-objcopy", "-O", "binary", str(elf), str(raw))
    artifacts = HERE.parents[3] / "tasks/jtcores-230/artifacts/boot-control-v7"
    artifacts.mkdir(parents=True, exist_ok=True)
    with (artifacts / "boot_control_v7.lst").open("w") as listing:
        subprocess.run(["m68k-linux-gnu-objdump", "-d", "-S", str(elf)],
                       check=True, stdout=listing)

    code = raw.read_bytes()
    if not code or len(code) >= min(PICO_WINDOW):
        raise SystemExit(f"image is {len(code)} bytes; must fit below PicoROM window")
    cpu = bytearray(b"\xff" * IMAGE_BYTES)
    cpu[:len(code)] = code
    cpu[0x1B800:0x1C000] = b"\xff" * 0x800
    a10, a5 = bytes(cpu[0::2]), bytes(cpu[1::2])
    if len(a10) != LANE_BYTES or len(a5) != LANE_BYTES:
        raise SystemExit("unexpected lane size")

    outputs = {
        "boot_control_v7_cpu.bin": bytes(cpu),
        "boot_control_v7_a10_even_high.bin": a10,
        "boot_control_v7_a5_odd_low.bin": a5,
    }
    for name, data in outputs.items():
        (HERE / name).write_bytes(data)

    report = {
        "board": "Taito X P0-039A Superman",
        "firmware_version": "v7",
        "purpose": "v6 boot qualification plus finite paced A10 transport heartbeat at the lower communication window; no timing suite",
        "capture_profile_id": "superman-p0-039a-boot-v7",
        "capture_profile": {
            "required_initial_markers_in_order": ["01", "02", "03", "10", "11", "12"],
            "heartbeat_marker": "04",
            "heartbeat_cpu_read_address": "0x01be08",
            "heartbeat_a10_physical_byte_address": "0x00df04",
            "heartbeat_event_address": "0x104",
            "heartbeat_read_count": 16,
            "heartbeat_nominal_spacing_ms": 102.401,
            "heartbeat_timing_basis": "two 68000 DBRA intervals: 65535 and 16383 taken branches at 10 cycles each, plus two 14-cycle loop exits, at nominal 8 MHz; interrupts and surrounding instructions add variable overhead",
            "required_complete_byte_sequence": ["01", "02", "03", "10", "11", "12"] + ["04"] * 16,
            "required_final_event_count": 22,
            "required_final_event_addresses": ["0x101", "0x102", "0x103", "0x110", "0x111", "0x112"] + ["0x104"] * 16,
            "fatal_marker": "1f",
            "duplicates_or_out_of_order": "fail except exactly 16 terminal heartbeat marker 04 reads",
            "timeout_before_all_22_markers": "fail",
            "terminal_behavior": "after the six boot markers and 16 heartbeat reads, set a gray backdrop and enter watchdog-serviced idle with no further PicoROM reads",
            "event_ring_limit": 31,
            "maximum_expected_fifo_bytes": 22,
            "image_binding": "full A10 and A5 SHA-256 readbacks",
        },
        "source": "boot_control_v7.s",
        "source_sha256": digest((HERE / "boot_control_v7.s").read_bytes()),
        "cpu_image_bytes": len(cpu),
        "lane_image_bytes": len(a10),
        "assembled_code_bytes": len(code),
        "reserved_cpu_window": "0x01b800-0x01bfff",
        "reserved_a10_physical_window": "0x00dc00-0x00dfff",
        "unused_former_v6_a10_window": "0x01dc00-0x01dfff",
        "boot_markers": ["01 reset entry", "02 watchdog write passed", "03 backdrop write passed", "10 work RAM passed", "11 display initialized", "12 32 VBL IRQ entries", "04 repeated 16 times as heartbeat", "1f fatal"],
        "irq_cadence_claim": "none; the 32-entry threshold proves handler execution only",
        "irq_level_policy": {
            "level_2": "IPL1 VBL; acknowledge 0x600000",
            "level_4": "IPL2 C-chip; acknowledge 0x300000",
            "level_6": "IPL1+IPL2; acknowledge both 0x600000 and 0x300000",
            "vbl_qualification": "32 combined level-2 and level-6 entries; level 4 counted separately",
        },
        "watchdog_service": "word 0x0010 to 0x400000 at reset, after long init phases, during polling/idle, in each IRQ, and between heartbeat delay intervals",
        "heartbeat_delay_loops": {"first_dbcc_count": 65536, "second_dbcc_count": 16384, "taken_branches": 81918, "cycles_at_10_taken_14_exit": 819208, "nominal_cpu_clock_hz": 8000000, "nominal_interval_ms": 102.401, "note": "Approximate interval only; surrounding instructions and interrupts add variable overhead; no physical timing claim"},
        "irq_counter_addresses": {"level_2": "0xF00000", "level_4": "0xF00002", "level_6": "0xF00004"},
        "sha256": {name: digest(data) for name, data in outputs.items()},
    }
    (HERE / "boot_manifest_v7.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
