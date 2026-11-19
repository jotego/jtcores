#!/usr/bin/env python3
"""Load, verify and bench-test Superman P0-039A PicoROM images over USB.

Uses the PicoROM packet protocol client in modules/jtkcpu/ver/pcb/tools/
pico_link.py (needs PyUSB), so the `picorom` CLI is not required.

  picorom_load.py list
  picorom_load.py load SUPERMAN-A10=a10.bin SUPERMAN-A5=a5.bin [--size 64k] [--xgecu]
  picorom_load.py pattern SUPERMAN-A5          # A0-A16 decode test, needs XGecu
  picorom_load.py xgecu-read out.bin           # read the chip in the XGecu

Every load writes the whole 128 KiB image, reads all of it back over USB and
compares SHA-256. With --xgecu (one unit only, sitting in the TL866II+), the
image is also read through the socket with `minipro -x` (no chip-ID read, so
no 12 V on A9) and compared. A JSON report goes to --out (default: a new
timestamped folder under tasks/jtcores-230/artifacts/).

Before touching a unit that is plugged into the PCB, the Shelly that powers
the board is queried and the command refuses to run unless it reports
output=false. Use --bench to skip that check when no unit is in the PCB.
PicoROM RAM is volatile: unplugging USB reloads the image stored in flash.
"""
import argparse
import datetime
import hashlib
import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TOOLS = ROOT / "modules/jtkcpu/ver/pcb/tools"
SIZE = 0x20000
MASKS = {"128k": 0x1FFFF, "64k": 0xFFFF}  # 27C010 (A0-A16) or A16 ignored
SHELLY = "http://192.168.68.52"
SHELLY_ID = "shellyplugsg3-d885ac147a10"
MINIPRO_DEV = "AM27C010@DIP32"
UNITS = {  # known Superman units: name -> USB serial prefix and socket
    "SUPERMAN-A10": ("E66430A64B572B21", "A10 even/high D15-D8"),
    "SUPERMAN-A5": ("E662505347335333", "A5 odd/low D7-D0"),
}

sys.path.insert(0, str(TOOLS))
try:
    import usb.core
    from pico_link import Pico
except ImportError as exc:
    sys.exit(f"{exc}. Run with a Python that has PyUSB, e.g. "
             f"tasks/jtcores-230/artifacts/pcb-boot-v3-venv/bin/python")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def connected():
    rows = []
    for d in usb.core.find(find_all=True, idVendor=0x2E8A, idProduct=0x000A):
        serial, _, name = d.serial_number.partition(":")
        rows.append({"serial": serial, "name": name})
    return rows


def info(name):
    p = Pico(name)
    try:
        out = {}
        for key in ("name", "build_config", "diag_version", "rom_enable", "addr_mask", "status"):
            try:
                out[key] = p.get(key)
            except RuntimeError as exc:
                out[key] = f"unavailable ({exc})"
        return out
    finally:
        p.close()


def check_unit(name):
    rows = {r["name"]: r["serial"] for r in connected()}
    if name not in rows:
        sys.exit(f"{name} is not connected. Found: {sorted(rows) or 'none'}")
    if name in UNITS and rows[name] != UNITS[name][0]:
        sys.exit(f"{name} has serial {rows[name]}, expected {UNITS[name][0]}")
    meta = info(name)
    if not meta["build_config"].startswith("POG_27C020"):
        sys.exit(f"{name} reports {meta['build_config']}; expected a POG_27C020 build")
    return {"serial": rows[name], **meta}


def shelly_off():
    def get(path):
        with urllib.request.urlopen(SHELLY + path, timeout=3) as r:
            return json.load(r)
    try:
        dev = get("/rpc/Shelly.GetDeviceInfo")
        st = get("/rpc/Switch.GetStatus?id=0")
    except OSError as exc:
        sys.exit(f"Cannot reach the Shelly at {SHELLY} ({exc}). "
                 "Confirm the PCB is off and use --bench only if no unit is in the PCB.")
    if dev.get("id") != SHELLY_ID:
        sys.exit(f"Unexpected device at {SHELLY}: {dev.get('id')}")
    if st.get("output") is not False:
        sys.exit(f"PCB power is on (Shelly output={st.get('output')}, "
                 f"{st.get('apower')} W). Switch it off before loading.")
    return {"id": dev["id"], "output": st["output"], "apower": st.get("apower")}


def write_verify(name, data, mask=MASKS["128k"]):
    """Upload following the jtkcpu firmware host contract
    (/nobackup/jtmisc/reverse/PicoROM, branch jtkcpu-1, firmware/README-jtkcpu.md):
    rom_enable=0, addr_mask (0x1ffff, or 0xffff for 64 KiB), write + full readback, ROM disabled for at
    least 3 s, then rom_enable=1. Stock firmware has no rom_enable parameter;
    there only the mask is set, as `picorom upload <name> <file> 1MBit` does."""
    p = Pico(name)
    try:
        try:
            p.set("rom_enable", "0")
            paused = time.monotonic()
        except RuntimeError:
            paused = None  # stock firmware
        # Setting addr_mask re-runs configure_address_pins(): A0-A16 for a
        # 27C010, A0-A15 for 64 KiB (A16 input disabled, upper half aliases).
        if p.set("addr_mask", f"0x{mask:x}") != f"0x{mask:08x}":
            raise RuntimeError(f"{name} did not accept addr_mask 0x{mask:x}")
        p.write(0, data)
        back = p.read(0, SIZE)
        if paused is not None:
            time.sleep(max(0.0, 3.0 - (time.monotonic() - paused)))
            p.set("rom_enable", "1")
    finally:
        p.close()
    return back


def xgecu_read(path):
    r = subprocess.run(["minipro", "-p", MINIPRO_DEV, "-x", "-r", str(path)],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"minipro failed ({r.returncode}): {r.stderr[-400:]}")
    return path.read_bytes()


def outdir(arg, label):
    d = Path(arg) if arg else ROOT / "tasks/jtcores-230/artifacts" / f"picorom-{label}-{now()}"
    d.mkdir(parents=True, exist_ok=True)
    return d


def cmd_list(args):
    rows = connected()
    if not rows:
        print("No PicoROM connected")
    for r in rows:
        meta = info(r["name"])
        known = UNITS.get(r["name"], ("", "unknown unit"))[1]
        print(f"{r['name']:14} {r['serial']}  {meta['build_config']}  "
              f"diag {meta['diag_version'].split(' ')[0]}  rom_enable {meta['rom_enable'].split(' ')[0]}  mask {meta['addr_mask']}  ({known})")


def cmd_load(args):
    jobs = []
    for item in args.pairs:
        name, sep, path = item.partition("=")
        if not sep:
            sys.exit(f"Expected NAME=IMAGE, got {item}")
        data = Path(path).read_bytes()
        if args.size == "64k" and len(data) == SIZE // 2:
            data += b"\xff" * (SIZE // 2)
        if len(data) != SIZE:
            sys.exit(f"{path} is {len(data)} bytes, expected {SIZE}")
        if args.size == "64k" and set(data[SIZE // 2:]) - {0xFF}:
            sys.exit(f"{path} has data above 64 KiB; it cannot run with --size 64k")
        jobs.append((name, Path(path).resolve(), data))
    if args.xgecu and len(jobs) != 1:
        sys.exit("--xgecu checks one unit at a time (the one in the programmer)")
    report = {"time_utc": now(), "size": args.size, "addr_mask": f"0x{MASKS[args.size]:x}", "units": []}
    report["power"] = "bench (not checked)" if args.bench else shelly_off()
    out = outdir(args.out, "load")
    ok = True
    for name, path, data in jobs:
        unit = check_unit(name)
        back = write_verify(name, data, MASKS[args.size])
        (out / f"readback-{name}.bin").write_bytes(back)
        row = {"name": name, **unit, "image": str(path), "image_sha256": sha(data),
               "usb_readback_sha256": sha(back), "usb_match": back == data}
        if args.xgecu:
            x = xgecu_read(out / f"xgecu-{name}.bin")
            # With 64 KiB the socket shows the lower half twice (A16 ignored).
            expect = data[:SIZE // 2] * 2 if args.size == "64k" else data
            row["xgecu_sha256"] = sha(x)
            row["xgecu_mismatches"] = sum(a != b for a, b in zip(x, expect))
            row["xgecu_match"] = x == expect
        ok &= row["usb_match"] and row.get("xgecu_match", True)
        report["units"].append(row)
        print(f"{name}: image {sha(data)[:12]}  usb {'OK' if row['usb_match'] else 'MISMATCH'}"
              + (f"  xgecu {'OK' if row['xgecu_match'] else str(row['xgecu_mismatches']) + ' bytes differ'}"
                 if args.xgecu else ""))
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Report: {out / 'report.json'}")
    sys.exit(0 if ok else 1)


def cmd_pattern(args):
    """Load three address-coding patterns and read each through the XGecu."""
    unit = check_unit(args.name)
    out = outdir(args.out, "pattern")
    pats = {"lo": bytes(i & 0xFF for i in range(SIZE)),
            "mid": bytes((i >> 8) & 0xFF for i in range(SIZE)),
            "hi": bytes(((i >> 16) & 1) * 0xFF for i in range(SIZE))}
    seen, report = {}, {"time_utc": now(), "unit": {"name": args.name, **unit}, "patterns": {}}
    for key, data in pats.items():
        back = write_verify(args.name, data)
        seen[key] = xgecu_read(out / f"xgecu-{key}.bin")
        report["patterns"][key] = {"usb_match": back == data,
                                   "xgecu_mismatches": sum(a != b for a, b in zip(seen[key], data))}
    stuck = {}
    for bit in range(17):
        hits = 0
        for i in range(SIZE):
            hi = seen["hi"][i]
            a = seen["lo"][i] | seen["mid"][i] << 8 | (1 if hi == 0xFF else 0) << 16
            hits += ((a ^ i) >> bit) & 1 or hi not in (0, 0xFF)
        stuck[f"A{bit}"] = hits
    report["wrong_reads_per_address_bit"] = stuck
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    for key, row in report["patterns"].items():
        print(f"{key:3}: usb {'OK' if row['usb_match'] else 'MISMATCH'}  "
              f"xgecu mismatches {row['xgecu_mismatches']}")
    bad = {k: v for k, v in stuck.items() if v}
    print("All of A0-A16 decode correctly" if not bad else f"Wrong address bits: {bad}")
    print(f"Report: {out / 'report.json'}. The unit now holds a test pattern: reload its image.")


def cmd_xgecu(args):
    data = xgecu_read(Path(args.file))
    print(f"{args.file}: {len(data)} bytes, sha256 {sha(data)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list", help="show connected PicoROMs").set_defaults(func=cmd_list)
    p = sub.add_parser("load", help="write images and verify full readback")
    p.add_argument("pairs", nargs="+", metavar="NAME=IMAGE")
    p.add_argument("--xgecu", action="store_true", help="also read through the TL866II+ socket")
    p.add_argument("--size", choices=sorted(MASKS), default="128k",
                   help="128k: 27C010 (A0-A16); 64k: ignore A16 (images must be blank above 64 KiB)")
    p.add_argument("--bench", action="store_true", help="skip the Shelly power-off check")
    p.add_argument("--out", help="report folder")
    p.set_defaults(func=cmd_load)
    p = sub.add_parser("pattern", help="A0-A16 decode test through the XGecu (bench only)")
    p.add_argument("name")
    p.add_argument("--out", help="report folder")
    p.set_defaults(func=cmd_pattern)
    p = sub.add_parser("xgecu-read", help="read the chip in the XGecu with minipro -x")
    p.add_argument("file")
    p.set_defaults(func=cmd_xgecu)
    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
