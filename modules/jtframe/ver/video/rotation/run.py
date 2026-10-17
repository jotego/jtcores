#!/usr/bin/env python3
"""Exercise the SiDi128 rotation RTL and SDRAM pins without a game core.

Run `python3 run.py --suite` for the self-contained CI regression (no ROMs or
snapshots required). A coordinate image checks every output column; every
cadence must also produce exactly the same complete frame. This catches pixel
loss even when the picture still looks plausible. For a new core, include its
raster size and enable cadence in the matrix below.

To reproduce issue #1672 before the fix:
    python3 run.py --rtl-ref fd182fbc6 --expect-loss --output /tmp/rotation-old
To render a MAME snapshot through the same RTL:
    python3 run.py /path/to/fshark/0003.png --output /tmp/rotation-mame

SiDi128 jtktiger runs at 49 MHz with a 7 MHz input pixel rate. Its doubled
pixel enable alternates between three and four system clocks. The old colour
pipeline advanced in system clocks, causing alternate columns to be duplicated
and discarded when sampled at those enables. Constant four-clock output
pixels (e.g. 48 MHz / 12 MHz) hide the defect. Both colour data and controls
must advance in output pixels to remain coherent for fractional enables.
"""
import argparse
from pathlib import Path
import subprocess
from PIL import Image

HERE = Path(__file__).resolve().parent
FRAME = HERE.parents[2]
REPO = FRAME.parents[1]


def coordinate_image(width, height):
    image = Image.new("RGB", (height, width))
    image.putdata([
        ((x % 32) << 3, (x // 32) << 3, (y % 32) << 3)
        for y in range(width) for x in range(height)
    ])
    return image


def build(directory, ref):
    sources = [
        HERE / "test.sv",
        FRAME / "hdl/video/jtframe_scan2x.v",
        FRAME / "hdl/video/jtframe_vtimer.v",
        FRAME / "hdl/ram/jtframe_dual_ram.v",
        FRAME / "hdl/clocking/jtframe_frac_cen.v",
        *sorted((FRAME / "hdl/video/rotate").glob("*.v")),
    ]
    if ref:
        old = directory / "rtl"
        old.mkdir(exist_ok=True)
        for index, source in enumerate(sources):
            if source.parent == FRAME / "hdl/video/rotate" or source.name == "jtframe_scan2x.v":
                # This elaboration-only fix avoids a zero-width constant slice
                # in old RTL; it does not change colour or pixel timing.
                if source.name == "scandoubler_scaledepth.v":
                    continue
                target = old / source.name
                target.write_bytes(subprocess.check_output(
                    ["git", "show", f"{ref}:{source.relative_to(REPO)}"], cwd=REPO))
                sources[index] = target
    with (directory / "build.log").open("w") as log:
        result = subprocess.run([
            "verilator", "--binary", "--timing", "-Wno-fatal",
            "--top-module", "test", "-DSIMULATION", "-DJTFRAME_VERTICAL",
            "-DJTFRAME_SDRAM_ROTATION", "--Mdir", str(directory / "obj_dir"),
            *map(str, sources),
        ], cwd=directory, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print((directory / "build.log").read_text())
        result.check_returncode()
    return directory / "obj_dir/Vtest"


def run(binary, directory, image, *, period=7, filtering=0, direction=1,
        fractional=0, realtiming=0):
    directory.mkdir(exist_ok=True)
    width, height = image.height, image.width
    raw = image.rotate(90, expand=True)
    (directory / "input.hex").write_text("".join(
        f"{((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3):04x}\n"
        for r, g, b in raw.getdata()))
    parameters = dict(period=period, filter=filtering, direction=direction,
                      fractional=fractional, realtiming=realtiming,
                      width=width, height=height,
                      htotal=446 if width == 320 else 384,
                      vtotal=286 if height == 240 else 264)
    with (directory / "sim.log").open("w") as log:
        subprocess.run([str(binary), *[f"+{k}={v}" for k, v in parameters.items()]],
                       cwd=directory, check=True, stdout=log, stderr=subprocess.STDOUT)
    rows, line = [], []
    for entry in (directory / "output.txt").open():
        hb, vb, pixel = entry.split()
        pixel = int(pixel, 16)
        if hb == "0" and vb == "0":
            line.append(tuple(((pixel >> shift) & 31) * 255 // 31
                              for shift in (10, 5, 0)))
        elif line:
            rows.append(line)
            line = []
    if line:
        rows.append(line)
    # Capturing one input frame can split an output line at the file boundary.
    if len(rows[0]) != width and len(rows[0]) + len(rows[-1]) == width:
        rows = [rows[-1] + rows[0], *rows[1:-1]]
    assert len(rows) == 2 * height, (directory, len(rows))
    assert all(len(row) == width for row in rows), directory
    output = Image.new("RGB", (width, 2 * height))
    output.putdata([pixel for row in rows for pixel in row])
    output.save(directory / "output.png")
    image.save(directory / "source.png")
    return output


def check_columns(image, height, direction, expect_loss):
    left = (image.width - height) // 2
    # Several interior rows avoid vertical blanking and frame-start prefetch.
    for y in (image.height // 4, image.height // 2, 3 * image.height // 4):
        decoded = []
        columns = range(image.width) if expect_loss else range(left, left + height)
        for x in columns:
            red, green, _ = image.getpixel((x, y))
            decoded.append(round(red * 31 / 255) + 32 * round(green * 31 / 255))
        expected = list(range(height))
        if direction == 2:
            expected.reverse()
        if expect_loss:
            assert len(set(decoded)) < height * 3 // 4, decoded
        else:
            assert decoded == expected, (y, decoded[:24], decoded[-24:])
    if not expect_loss:
        # Blue encodes the source row modulo 32. Unwrap the monotonic sequence
        # to verify every row survives vertical scaling, in either direction.
        source_rows = []
        for y in range(image.height):
            red, green, blue = image.getpixel((image.width // 2, y))
            if red or green:  # Exclude the scaler's trailing blank lines.
                source_rows.append(round(blue * 31 / 255))
        assert source_rows[0] == (0 if direction == 1 else (image.width - 1) % 32)
        deltas = [((b - a) if direction == 1 else (a - b)) % 32
                  for a, b in zip(source_rows, source_rows[1:])]
        assert all(delta in (0, 1) for delta in deltas), "source rows skipped"
        assert sum(deltas) + 1 == image.width, "source rows lost"
    return len(set(decoded))


def check_interpolator(directory):
    with (directory / "interp-build.log").open("w") as log:
        subprocess.run([
            "verilator", "--binary", "--timing", "-Wno-fatal",
            "--top-module", "interp_test", "--Mdir", str(directory / "interp_obj"),
            str(HERE / "interp_test.sv"),
            str(FRAME / "hdl/video/rotate/pixel_interp.v"),
        ], check=True, stdout=log, stderr=subprocess.STDOUT)
    subprocess.run([str(directory / "interp_obj/Vinterp_test")], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", nargs="?", type=Path)
    parser.add_argument("--period", type=int, default=7)
    parser.add_argument("--filter", type=int, choices=(0, 1), default=0)
    parser.add_argument("--direction", type=int, choices=(1, 2), default=1)
    parser.add_argument("--fractional", type=int, choices=(0, 1), default=0)
    parser.add_argument("--realtiming", type=int, choices=(0, 1), default=0)
    parser.add_argument("--suite", action="store_true")
    parser.add_argument("--rtl-ref", help="read rotation RTL from this git revision")
    parser.add_argument("--expect-loss", action="store_true", help="assert the old defect reproduces")
    parser.add_argument("--output", type=Path, default=HERE / "build")
    args = parser.parse_args()
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    binary = build(directory, args.rtl_ref)
    if args.suite:
        assert not args.snapshot and not args.expect_loss
        check_interpolator(directory)
        for width, height in ((320, 240), (256, 224)):
            for direction in (1, 2):
                reference = None
                for period in (6, 7, 8, 9, 10, 11, 12, 16):
                    name = f"{width}x{height}-r{direction}-p{period}"
                    result = run(binary, directory / name, coordinate_image(width, height),
                                 period=period, direction=direction)
                    count = check_columns(result, height, direction, False)
                    if reference is None:
                        reference = result.tobytes()
                    assert result.tobytes() == reference, (name, "cadence changed pixels")
                    print(f"PASS {name}: {count} distinct columns", flush=True)
                name = f"{width}x{height}-r{direction}-fractional"
                result = run(binary, directory / name, coordinate_image(width, height),
                             direction=direction, fractional=1)
                check_columns(result, height, direction, False)
                assert result.tobytes() == reference, (name, "cadence changed pixels")
                print(f"PASS {name}", flush=True)
                filtered_reference = None
                for period, fractional in ((7, 0), (8, 0), (7, 1)):
                    name = f"{width}x{height}-r{direction}-filter-p{period}-frac{fractional}"
                    result = run(binary, directory / name, coordinate_image(width, height),
                                 direction=direction, period=period,
                                 fractional=fractional, filtering=1)
                    if filtered_reference is None:
                        filtered_reference = result.tobytes()
                    assert result.tobytes() == filtered_reference, (name, "filtered cadence changed pixels")
                    print(f"PASS {name}", flush=True)
    else:
        image = (Image.open(args.snapshot).convert("RGB") if args.snapshot
                 else coordinate_image(320, 240))
        result = run(binary, directory / "capture", image, period=args.period,
                     direction=args.direction, filtering=args.filter,
                     fractional=args.fractional, realtiming=args.realtiming)
        if not args.snapshot and not args.filter:
            count = check_columns(result, image.width, args.direction, args.expect_loss)
            print(f"{'Reproduced loss' if args.expect_loss else 'PASS'}: {count} distinct columns")
        print(directory / "capture/output.png")


if __name__ == "__main__":
    main()
