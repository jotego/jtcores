#!/usr/bin/env python3
"""Validate framed timing results and the PicoROM fixed-count event trace."""
from __future__ import annotations

import argparse
import json
import statistics
import struct
import sys
import zlib
from pathlib import Path

FRAME_BYTES = 27
PAYLOAD_BYTES = 16
EXPECTED_BUILD_ID = 0x2303
BOOT_EVENTS = [0x101, 0x110, 0x111, 0x112]
FIXED_MARKERS = list(range(0x020, 0x038))


class InvalidCapture(ValueError):
    pass


def crc16_ccitt(data: bytes) -> int:
    crc = 0xffff
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xffff if crc & 0x8000 else (crc << 1) & 0xffff
    return crc


def be16(data: bytes, offset: int = 0) -> int:
    return int.from_bytes(data[offset:offset + 2], "big")


def be32(data: bytes, offset: int = 0) -> int:
    return int.from_bytes(data[offset:offset + 4], "big")


def decode_frames(raw: bytes, manifest: dict) -> dict:
    if len(raw) == 0 or len(raw) % FRAME_BYTES:
        raise InvalidCapture(f"frame stream length {len(raw)} is not a nonzero multiple of 27")
    frames = []
    for index in range(0, len(raw), FRAME_BYTES):
        frame = raw[index:index + FRAME_BYTES]
        if frame[:3] != b"\xa5\x5a\x02":
            raise InvalidCapture(f"frame {index // FRAME_BYTES}: bad sync or protocol version")
        if be16(frame, 3) != EXPECTED_BUILD_ID:
            raise InvalidCapture(f"frame {index // FRAME_BYTES}: unexpected build ID 0x{be16(frame, 3):04x}")
        if be16(frame, 5) != len(frames):
            raise InvalidCapture(f"frame {index // FRAME_BYTES}: sequence {be16(frame, 5)} is not contiguous")
        if frame[7] != PAYLOAD_BYTES:
            raise InvalidCapture(f"frame {index // FRAME_BYTES}: payload length {frame[7]} is not 16")
        expected_crc = crc16_ccitt(frame[:25])
        if int.from_bytes(frame[25:27], "big") != expected_crc:
            raise InvalidCapture(f"frame {index // FRAME_BYTES}: CRC16 mismatch")
        frames.append((frame[8], frame[9:25]))

    if len(frames) < 5:
        raise InvalidCapture("too few result frames")
    if frames[0][0] != 0x01 or frames[1][0] != 0x02 or frames[2][0] != 0x04:
        raise InvalidCapture("metadata, range/CRC, and IRQ summary frames are missing or out of order")
    meta, extent, irq = frames[0][1], frames[1][1], frames[2][1]
    image_crc, suite_crc, run_id = be32(meta, 0), be32(meta, 4), be32(meta, 8)
    run_count, samples_per_run, sample_count = meta[12], meta[13], be16(meta, 14)
    manifest_image = int(manifest["image_crc32"], 16)
    manifest_suite = int(manifest["suite_crc32"], 16)
    run_order = manifest["run_order"]
    expected_samples = len(run_order) * int(manifest["steady_samples_per_run"])
    if image_crc != manifest_image:
        raise InvalidCapture(f"image identity mismatch: frame 0x{image_crc:08x}, manifest 0x{manifest_image:08x}")
    if suite_crc != manifest_suite:
        raise InvalidCapture(f"suite identity mismatch: frame 0x{suite_crc:08x}, manifest 0x{manifest_suite:08x}")
    if run_count != len(run_order) or samples_per_run != manifest["steady_samples_per_run"] or sample_count != expected_samples:
        raise InvalidCapture("run/sample inventory does not match the timing manifest")

    results_crc = be32(extent, 0)
    range_start, range_end = be32(extent, 4), be32(extent, 8)
    result_bytes, data_frame_count = be16(extent, 12), be16(extent, 14)
    expected_data_frames = (expected_samples + 3) // 4
    if result_bytes != expected_samples * 4 or data_frame_count != expected_data_frames:
        raise InvalidCapture("result byte/frame inventory is inconsistent")
    expected_range_start = int(manifest["sample_storage_cpu_address"], 16)
    expected_range_end = expected_range_start + len(run_order) * (int(manifest["steady_samples_per_run"]) + 1) * 4
    if range_start != expected_range_start or range_end != expected_range_end:
        raise InvalidCapture("sample storage range does not match the manifest stride")

    irq2, irq4, irq6, selected_level = (be32(irq, offset) for offset in (0, 4, 8, 12))
    total_irq = irq2 + irq4 + irq6
    if selected_level not in (2, 6) or (irq2 if selected_level == 2 else irq6) == 0:
        raise InvalidCapture("selected IRQ level is absent from the captured counters")
    if irq2 and irq6:
        raise InvalidCapture(f"mixed IRQ sources invalidate per-frame samples: IRQ2={irq2}, IRQ6={irq6}")
    if irq2 + irq6 < run_count * (samples_per_run + 1):
        raise InvalidCapture("IRQ counters are too small for the completed run/sample inventory")

    expected_frames = 3 + expected_data_frames + 1
    if len(frames) != expected_frames:
        raise InvalidCapture(f"expected {expected_frames} frames, received {len(frames)}")
    values = []
    for frame_index in range(expected_data_frames):
        flag, payload = frames[3 + frame_index]
        if flag != 0x10:
            raise InvalidCapture(f"frame {3 + frame_index}: expected data flag 0x10")
        values.extend(struct.unpack(">4I", payload))
    values = values[:expected_samples]
    if len(values) != expected_samples or any(value == 0 for value in values):
        raise InvalidCapture("sample inventory is short or contains a zero loop count")
    wire_data = b"".join(struct.pack(">I", value) for value in values)
    actual_crc = zlib.crc32(wire_data) & 0xffffffff
    if actual_crc != results_crc:
        raise InvalidCapture(f"sample CRC32 mismatch: frame 0x{results_crc:08x}, calculated 0x{actual_crc:08x}")
    terminal_flag, terminal = frames[-1]
    if terminal_flag != 0x20 or be32(terminal, 0) != results_crc or \
            be16(terminal, 4) != expected_samples or be16(terminal, 6) != expected_data_frames or \
            terminal[8:] != bytes(8):
        raise InvalidCapture("terminal frame does not match the sample inventory/CRC")
    expected_run_id = image_crc ^ suite_crc ^ results_crc
    if run_id != expected_run_id:
        raise InvalidCapture("run ID does not match image, suite, and result CRCs")

    records = []
    for run_index, label in enumerate(run_order):
        first = run_index * samples_per_run
        records.append({"run": run_index, "label": label, "samples": values[first:first + samples_per_run]})
    return {
        "image_crc32": f"{image_crc:08x}",
        "suite_crc32": f"{suite_crc:08x}",
        "results_crc32": f"{results_crc:08x}",
        "run_id": f"{expected_run_id:08x}",
        "result_range": {"start": f"0x{range_start:08x}", "end": f"0x{range_end:08x}", "wire_bytes": result_bytes},
        "interrupts": {
            "irq2": irq2, "irq4": irq4, "irq6": irq6, "selected_level": selected_level,
            "total": total_irq, "mixed_vblank_sources": False,
            "irq4_non_vblank_present": irq4 > 0,
            "per_frame_comparison_qualified": irq4 == 0,
            "irq4_overhead_note": (
                "IRQ4 is acknowledged and counted but excluded from frame sampling; its separate handler overhead "
                "is not assigned to individual frame samples"
            ) if irq4 else None,
            "expected_level": int(manifest.get("expected_irq_level", 6)),
            "expected_level_match": selected_level == int(manifest.get("expected_irq_level", 6)),
        },
        "runs": records,
        "frame_count": len(frames),
    }


def parse_int(value) -> int:
    if isinstance(value, int):
        return value
    return int(value, 0)


def check_events(path: Path | dict, manifest: dict) -> dict:
    capture = path if isinstance(path, dict) else json.loads(path.read_text())
    if capture.get("magic") != "PICO":
        raise InvalidCapture("event snapshot magic is not PICO")
    if capture.get("active") not in (True, 1):
        raise InvalidCapture("PicoROM capture was not active")
    if int(capture.get("dropped_bytes", -1)) != 0:
        raise InvalidCapture("PicoROM capture reports dropped bytes")
    if capture.get("capture_stopped") is not False:
        raise InvalidCapture("PicoROM capture stopped or has no explicit healthy status")
    events = capture.get("events")
    if not isinstance(events, list):
        raise InvalidCapture("event snapshot has no events array")
    if len(events) != 28:
        raise InvalidCapture(f"expected 28 events (4 stage markers + 24 timing markers), received {len(events)}")
    if int(capture.get("count", -1)) != len(events):
        raise InvalidCapture("stable event header count does not match returned ring entries")
    codes = [parse_int(event["address"]) for event in events]
    if any(code < 0 or code > 0x1ff for code in codes):
        raise InvalidCapture("event address is not a low-nine-bit recorder address")
    expected_codes = BOOT_EVENTS[:3] + FIXED_MARKERS + BOOT_EVENTS[3:]
    if codes != expected_codes:
        raise InvalidCapture("event identity/order mismatch; expected 01/10/11, marker IDs 0x020..0x037, then 12")
    seqs = [parse_int(event.get("sequence", -1)) for event in events]
    if seqs != list(range(28)):
        raise InvalidCapture("fresh event session sequence must be contiguous from 0 through 27")
    times = [parse_int(event["time_us"]) & 0xffffffff for event in events]
    brackets = manifest["fixed_count_mode"]["brackets"]
    durations = []
    for index, bracket in enumerate(brackets):
        start = times[3 + index * 2]
        end = times[4 + index * 2]
        delta = (end - start) & 0xffffffff
        if delta > 300_000_000:
            raise InvalidCapture(f"fixed-count bracket duration {delta} us exceeds the bounded capture window")
        if bracket["count"] and delta == 0:
            raise InvalidCapture(f"N={bracket['count']} bracket has zero elapsed microseconds")
        durations.append({"count": bracket["count"], "repetition": bracket["repetition"], "duration_us": delta})
    fit_rows = [entry for entry in durations if entry["count"] > 0]
    xs = [entry["count"] for entry in fit_rows]
    ys = [entry["duration_us"] for entry in fit_rows]
    mean_x, mean_y = statistics.mean(xs), statistics.mean(ys)
    denom = sum((x - mean_x) ** 2 for x in xs)
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / denom if denom else 0.0
    means = {str(count): statistics.mean(row["duration_us"] for row in durations if row["count"] == count)
             for count in (0, 128, 256, 512)}
    return {
        "event_count": len(events),
        "capture_health": {"active": True, "dropped_bytes": 0, "capture_stopped": False},
        "fixed_count_brackets": durations,
        "mean_duration_us_by_count": means,
        "least_squares_us_per_dbra_iteration": slope,
        "fit_excludes_n0_control": True,
        "timing_source": "RP2040 event timestamps (1 us resolution), not CPU edge/cycle timestamps",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frames", required=True, type=Path,
                        help="concatenated 27-byte PicoROM type-2 response frames")
    parser.add_argument("--events", required=True, type=Path,
                        help="JSON output from Pico.events(base), wrapped with active/dropped_bytes/capture_stopped")
    parser.add_argument("--manifest", type=Path,
                        default=Path(__file__).with_name("timing_manifest.json"))
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text())
        frames = decode_frames(args.frames.read_bytes(), manifest)
        events = check_events(args.events, manifest)
        report = {"status": "valid", "frames": frames, "events": events}
    except (OSError, KeyError, ValueError, TypeError, json.JSONDecodeError) as exc:
        report = {"status": "invalid", "error": str(exc)}
        print(json.dumps(report, indent=2), file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
