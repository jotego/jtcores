#!/usr/bin/env python3
"""Bounded Superman timing capture using the existing POG/PicoROM client."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
HELPER = ROOT / "tasks/jtcores-230/scripts/superman_pcb.py"
MAX_SECONDS = 300
CAPTURE_BASE = 0x0DC00
MARKERS = (0x01, 0x10, 0x11, 0x12)
FRAME_BYTES = 27


class CaptureError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_helper():
    if not HELPER.is_file():
        raise CaptureError(f"Required boot preparation helper is missing: {HELPER}")
    spec = importlib.util.spec_from_file_location("superman_pcb_helper", HELPER)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_decode():
    spec = importlib.util.spec_from_file_location("timing_decode", HERE / "timing_decode.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


LANE_MASK = 0xFFFF  # 64 KiB per lane: the v2 image never uses A16


def verify_preparation(helper, preparation_path: Path, manifest: dict) -> dict:
    """Accept a picorom_load.py `load --size 64k` report for both lanes."""
    prepared = json.loads(preparation_path.read_text())
    if prepared.get("size") != "64k" or prepared.get("addr_mask") != f"0x{LANE_MASK:x}":
        raise CaptureError("Preparation report is not a 64 KiB (addr_mask 0xffff) load")
    required = {
        "SUPERMAN-A10": manifest["sha256"]["timing_a10_even_high.bin"],
        "SUPERMAN-A5": manifest["sha256"]["timing_a5_odd_low.bin"],
    }
    rows = {row["name"]: row for row in prepared.get("units", [])}
    if set(rows) != set(required):
        raise CaptureError(f"Preparation report must cover exactly {sorted(required)}")
    for name, expected_hash in required.items():
        row = rows[name]
        if row.get("serial") != helper.UNITS[name]["usb_id"]:
            raise CaptureError(f"Preparation report USB ID mismatch for {name}")
        if row.get("image_sha256") != expected_hash or row.get("usb_match") is not True:
            raise CaptureError(f"Preparation report for {name} lacks a verified load of this timing image")
        source = Path(row["image"])
        if not source.is_file() or sha256(source.read_bytes()) != expected_hash:
            raise CaptureError(f"Timing lane image changed or is missing: {source}")
    return prepared


def frame_crc16(frame_prefix: bytes) -> int:
    crc = 0xffff
    for byte in frame_prefix:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xffff if crc & 0x8000 else (crc << 1) & 0xffff
    return crc


def validate_frame(frame: bytes, expected_sequence: int) -> None:
    if len(frame) != FRAME_BYTES or frame[:3] != b"\xa5\x5a\x02":
        raise CaptureError("Malformed timing response frame sync/version")
    build_id = int.from_bytes(frame[3:5], "big")
    sequence = int.from_bytes(frame[5:7], "big")
    if build_id != 0x2303 or sequence != expected_sequence or frame[7] != 16:
        raise CaptureError(
            f"Unexpected timing frame identity/build/sequence/length: "
            f"build=0x{build_id:04x} sequence={sequence} length={frame[7]}"
        )
    if int.from_bytes(frame[25:27], "big") != frame_crc16(frame[:25]):
        raise CaptureError(f"Timing frame {sequence} failed CRC16-CCITT")


def framed_exchange(pico, raw_capture: bytearray, expected_frames: int, timeout: int) -> None:
    # CommsData payloads are the PicoROM RX bytes observed at 0x01b818/0x01bc00.
    # 'G' requests the suite; each ACK echoes the low byte of a frame sequence.
    pico.send(82, b"G")
    deadline = time.monotonic() + timeout
    pending = bytearray()
    sequence = 0
    while sequence < expected_frames and time.monotonic() < deadline:
        batch = pico.poll()
        raw_capture.extend(batch)
        pending.extend(batch)
        while len(pending) >= FRAME_BYTES and sequence < expected_frames:
            frame = bytes(pending[:FRAME_BYTES])
            del pending[:FRAME_BYTES]
            validate_frame(frame, sequence)
            pico.send(82, bytes((sequence & 0xff,)))
            sequence += 1
        if not pending or len(pending) < FRAME_BYTES:
            time.sleep(0.01)
    if sequence != expected_frames:
        raise CaptureError(f"Timed out after {sequence}/{expected_frames} acknowledged frames")
    if pending:
        raise CaptureError(f"Unexpected trailing bytes after terminal frame: {pending.hex()}")
    trailing = pico.poll()
    raw_capture.extend(trailing)
    if trailing:
        raise CaptureError(f"Unexpected extra PicoROM response bytes after results: {trailing.hex()}")


def capture(args) -> dict:
    helper = load_helper()
    decoder = load_decode()
    manifest_path = HERE / "timing_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    preparation_path = Path(args.preparation_report)
    prepared = verify_preparation(helper, preparation_path, manifest)
    protocol_doc = Path(args.protocol_doc)
    if not protocol_doc.is_file() or "0x0dc00" not in protocol_doc.read_text().lower():
        raise CaptureError("A protocol note documenting the reserved 0x0dc00 window is required")
    if not args.power_on:
        raise CaptureError("This capture requires explicit --power-on authorization")
    if not 1 <= args.timeout <= MAX_SECONDS:
        raise CaptureError(f"--timeout must be 1..{MAX_SECONDS} seconds")
    outdir = Path(args.output_dir)
    helper.fresh_output(outdir)
    report_path = outdir / "timing-capture-report.json"
    frames_path = outdir / "timing_frames.bin"
    markers_path = outdir / "timing_marker_bytes.bin"
    events_path = outdir / "timing_events.json"
    report = {
        "created_utc": utc_now(),
        "board": manifest["board"],
        "image_crc32": manifest["image_crc32"],
        "suite_crc32": manifest["suite_crc32"],
        "image_sha256": manifest["sha256"],
        "preparation_report": str(preparation_path.resolve()),
        "preparation_report_sha256": sha256(preparation_path.read_bytes()),
        "protocol_document": str(protocol_doc.resolve()),
        "protocol_document_sha256": sha256(protocol_doc.read_bytes()),
        "capture_base": hex(CAPTURE_BASE),
        "timeout_seconds": args.timeout,
        "initial_event_state": None,
        "pre_capture_readbacks": [],
        "boot_markers": [],
        "event_snapshot": None,
        "frames_file": str(frames_path.resolve()),
        "events_file": str(events_path.resolve()),
        "marker_bytes_file": str(markers_path.resolve()),
        "frame_count": 0,
        "power_on": None,
        "power_off": None,
        "status": "incomplete",
    }
    pico = None
    comms_started = False
    power_attempted = False
    raw_frames = bytearray()
    raw_markers = bytearray()
    event_doc = None
    try:
        report["shelly_off_before"] = helper.require_off(args.shelly_url)
        masks = {name: LANE_MASK for name in ("SUPERMAN-A10", "SUPERMAN-A5")}
        report["devices_before"] = helper.inspect_units(masks)
        # Re-read both complete volatile ROM images immediately before capture,
        # before CommsStart overlays the A10 window header.
        FramedPico = helper.import_pico()
        for row in prepared["units"]:
            name = row["name"]
            readback_path = outdir / f"pre-capture-{name}.bin"
            reader = FramedPico(name)
            try:
                data = reader.read(0, 0x20000)
            finally:
                reader.close()
            readback_path.write_bytes(data)
            expected = manifest["sha256"]["timing_a10_even_high.bin" if name == "SUPERMAN-A10" else "timing_a5_odd_low.bin"]
            if sha256(data) != expected:
                raise CaptureError(f"Full live readback hash mismatch for {name}")
            report["pre_capture_readbacks"].append({
                "name": name, "path": str(readback_path.resolve()),
                "bytes": len(data), "sha256": sha256(data), "matches_manifest": True,
            })
        pico = FramedPico("SUPERMAN-A10")
        serial = str(pico.dev.serial_number or "")
        if not serial.upper().startswith("E66430A64B572B21:SUPERMAN-A10"):
            raise CaptureError(f"Unexpected A10 PicoROM USB identity: {serial!r}")
        comms_started = True
        pico.start(CAPTURE_BASE)
        report["initial_event_state"] = helper.event_health(pico, CAPTURE_BASE)
        if report["initial_event_state"].get("count") != 0:
            raise CaptureError("Fresh CommsStart event count must be zero")
        report["shelly_off_before_power_on"] = helper.require_off(args.shelly_url)
        power_attempted = True
        report["power_on"] = helper.set_power(args.shelly_url, True)

        marker_stream = bytearray()
        marker_index = 0
        deadline = time.monotonic() + args.timeout
        while marker_index < len(MARKERS) and time.monotonic() < deadline:
            batch = pico.poll()
            raw_markers.extend(batch)
            for value in batch:
                if marker_index >= len(MARKERS) or value != MARKERS[marker_index]:
                    raise CaptureError(f"Unexpected boot marker 0x{value:02x} at index {marker_index}")
                marker_stream.append(value)
                report["boot_markers"].append(value)
                marker_index += 1
            if marker_index < len(MARKERS):
                time.sleep(0.02)
        if marker_index != len(MARKERS):
            raise CaptureError(f"Boot/suite marker timeout: {marker_stream.hex(' ')}")

        event_state = helper.event_health(pico, CAPTURE_BASE)
        event_doc = {
            "magic": event_state["magic"],
            "active": event_state["active"],
            "count": event_state["count"],
            "dropped_bytes": event_state["dropped_bytes"],
            "capture_stopped": event_state["capture_stopped"],
            "events": event_state["events"],
        }
        report["event_snapshot"] = event_doc
        # Check the fresh bounded event inventory before TX frames can replace it.
        decoder.check_events(event_doc, manifest)

        expected_frames = 3 + (len(manifest["run_order"]) * manifest["steady_samples_per_run"] + 3) // 4 + 1
        remaining = int(deadline - time.monotonic())
        if remaining < 1:
            raise CaptureError("Bounded capture window expired before result exchange")
        framed_exchange(pico, raw_frames, expected_frames, remaining)
        report["frame_count"] = len(raw_frames) // FRAME_BYTES
        report["frames_sha256"] = sha256(raw_frames)
        decoded = decoder.decode_frames(bytes(raw_frames), manifest)
        decoder.check_events(event_doc, manifest)
        report["decoded_results"] = decoded
        report["event_analysis"] = decoder.check_events(event_doc, manifest)
        final_event_state = helper.event_health(pico, CAPTURE_BASE)
        report["final_event_state"] = final_event_state
        helper.validate_event_health(final_event_state)
        report["status"] = "complete"
        report["validated"] = True
    except Exception as exc:
        report["status"] = "failed"
        report["validated"] = False
        report["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        if comms_started and pico is not None:
            try:
                pico.end()
                report["capture_end_sent"] = True
            except Exception as exc:
                report["capture_end_error"] = f"{type(exc).__name__}: {exc}"
                report["status"] = "failed"
        if power_attempted:
            try:
                report["power_off"] = helper.set_power(args.shelly_url, False)
            except Exception as exc:
                report["power_off_error"] = f"{type(exc).__name__}: {exc}"
                try:
                    info, status = helper.checked_shelly(args.shelly_url)
                    report["power_state_after_cleanup"] = {
                        "device": info, "switch": status, "observed_utc": utc_now(),
                    }
                    report["status"] = (
                        "failed_power_off_board_on" if status.get("output") is True
                        else "failed_power_off_board_off"
                    )
                except Exception as state_exc:
                    report["power_state_check_error"] = f"{type(state_exc).__name__}: {state_exc}"
                    report["status"] = "failed_power_state_unknown"
        if pico is not None:
            try:
                pico.close()
            except Exception as exc:
                report["usb_close_error"] = f"{type(exc).__name__}: {exc}"
                if report.get("status") not in {
                    "failed_power_off_board_on", "failed_power_off_board_off",
                    "failed_power_state_unknown",
                }:
                    report["status"] = "failed"
        # Write artifacts only after CommsEnd, relay-off verification, and USB
        # release have been attempted, so a storage failure cannot skip cleanup.
        try:
            frames_path.write_bytes(raw_frames)
            markers_path.write_bytes(raw_markers)
            if event_doc is not None:
                events_path.write_text(json.dumps(event_doc, indent=2) + "\n")
            report["frame_count"] = len(raw_frames) // FRAME_BYTES
            report["frames_sha256"] = sha256(raw_frames)
            report["marker_bytes"] = raw_markers.hex()
            report["marker_bytes_sha256"] = sha256(raw_markers)
        except Exception as exc:
            report["artifact_write_error"] = f"{type(exc).__name__}: {exc}"
            report["status"] = "failed_artifact_write"
        report["validated"] = report.get("status") == "complete"
        report["completed_utc"] = utc_now()
        try:
            report_path.write_text(json.dumps(report, indent=2) + "\n")
        except Exception as exc:
            report["report_write_error"] = f"{type(exc).__name__}: {exc}"
            report["status"] = "failed_report_write"
            report["validated"] = False
    print(json.dumps(report, indent=2))
    return report


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preparation-report", required=True)
    parser.add_argument("--protocol-doc", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--shelly-url", required=True)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--power-on", action="store_true",
                        help="explicitly authorize bounded power-on after the event recorder is armed")
    args = parser.parse_args(argv)
    try:
        report = capture(args)
    except (CaptureError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        parser.exit(2, f"error: {exc}\n")
    return 0 if report["status"] == "complete" else 1


if __name__ == "__main__":
    raise SystemExit(main())
