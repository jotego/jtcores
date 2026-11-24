#!/usr/bin/env python3
"""Build the Superman P0-039A boot-control image and both byte-lane ROMs."""
from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMAGE_BYTES = 0x40000
LANE_BYTES = IMAGE_BYTES // 2
PICO_WINDOW = range(0x3B800, 0x3C000)


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


with tempfile.TemporaryDirectory(prefix="taitox-boot-") as temp:
    temp_dir = Path(temp)
    obj = temp_dir / "boot_control.o"
    elf = temp_dir / "boot_control.elf"
    raw = temp_dir / "raw.bin"
    run("m68k-linux-gnu-as", "-m68000", "-g", "-o", str(obj),
        str(HERE / "boot_control.s"))
    run("m68k-linux-gnu-ld", "-T", str(HERE / "layout.ld"), "-o", str(elf),
        str(obj))
    run("m68k-linux-gnu-objcopy", "-O", "binary", str(elf), str(raw))
    task_artifacts = HERE.parents[3] / "tasks/jtcores-230/artifacts/boot-control"
    task_artifacts.mkdir(parents=True, exist_ok=True)
    with (task_artifacts / "boot_control.lst").open("w") as listing:
        subprocess.run(["m68k-linux-gnu-objdump", "-d", "-S", str(elf)],
                       check=True, stdout=listing)

    code = raw.read_bytes()
    if not code or len(code) >= min(PICO_WINDOW):
        raise SystemExit(f"image is {len(code)} bytes; must fit below PicoROM window")
    if len(code) > IMAGE_BYTES:
        raise SystemExit(f"image is {len(code)} bytes; exceeds low CPU ROM span")
    cpu = bytearray(b"\xff" * IMAGE_BYTES)
    cpu[:len(code)] = code
    # Keep the entire A10 communication window available to CommsStart.
    cpu[0x3B800:0x3C000] = b"\xff" * 0x800
    hi = bytes(cpu[0::2])
    lo = bytes(cpu[1::2])
    assert len(hi) == len(lo) == LANE_BYTES

    outputs = {
        "boot_control_cpu.bin": bytes(cpu),
        "boot_control_a10_even_high.bin": hi,
        "boot_control_a5_odd_low.bin": lo,
    }
    for name, data in outputs.items():
        (HERE / name).write_bytes(data)

    report = {
        "board": "Taito X P0-039A Superman",
        "firmware_version": "v5",
        "purpose": "boot-entry, watchdog, and IRQ qualification only; no timing suite",
        "capture_profile_id": "superman-p0-039a-boot-v5",
        "capture_profile": {
            "required_markers_in_order": ["01", "02", "03", "10", "11", "12"],
            "fatal_marker": "1f",
            "duplicates_or_out_of_order": "fail",
            "timeout_before_terminal_marker": "fail",
            "image_binding": "full A10 and A5 SHA-256 readbacks",
        },
        "source": "boot_control.s",
        "source_sha256": digest((HERE / "boot_control.s").read_bytes()),
        "cpu_image_bytes": len(cpu),
        "lane_image_bytes": len(hi),
        "assembled_code_bytes": len(code),
        "reserved_cpu_window": "0x03b800-0x03bfff",
        "reserved_a10_physical_window": "0x01dc00-0x01dfff",
        "boot_markers": ["01 reset entry", "02 watchdog write passed", "03 backdrop write passed", "10 work RAM passed", "11 display initialized", "12 32 VBL IRQ entries", "1f fatal"],
        "irq_cadence_claim": "none; the 32-entry threshold proves handler execution only",
        "irq_level_policy": {
            "level_2": "IPL1 VBL; acknowledge 0x600000",
            "level_4": "IPL2 C-chip; acknowledge 0x300000",
            "level_6": "IPL1+IPL2; acknowledge both 0x600000 and 0x300000",
            "vbl_qualification": "32 combined level-2 and level-6 entries; level 4 counted separately",
        },
        "watchdog_service": "write word 0x0010 to 0x400000 at reset, after long init phases, during polling/idle, and in each accepted IRQ",
        "irq_counter_addresses": {
            "level_2": "0xF00000",
            "level_4": "0xF00002",
            "level_6": "0xF00004",
        },
        "sha256": {name: digest(data) for name, data in outputs.items()},
    }
    (HERE / "boot_manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
