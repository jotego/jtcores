#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check active-line continuity and sync while changing the width option."""
from pathlib import Path
import subprocess
import tempfile

here = Path(__file__).resolve().parent
core = here.parent.parent
frame = core.parent.parent / "modules/jtframe/hdl"

with tempfile.TemporaryDirectory(prefix="mzone-width-") as tmp:
    tmp = Path(tmp)
    # Pixel fetchers cannot affect sync/blanking. Keep their actual interfaces
    # while omitting graphics RAM/ROM dependencies from this timing-only test.
    stubs = []
    for name in ("scroll", "fix", "obj"):
        source = (core / f"hdl/jtmzone_{name}.v").read_text()
        source = source[source.index("module "):]
        stubs.append(source[:source.index(");") + 2] + "\nendmodule\n")
    stub_file = tmp / "fetchers.v"
    stub_file.write_text("\n".join(stubs))
    binary = tmp / "test"
    subprocess.run([
        "iverilog", "-g2012", "-DSIMULATION", "-s", "tb", "-o", str(binary),
        str(here / "tb.v"), str(stub_file),
        str(core / "hdl/jtmzone_video.v"),
        str(core / "hdl/jtmzone_colmix.v"),
        str(frame / "video/jtframe_vtimer.v"),
        str(frame / "video/jtframe_blank.v"),
        str(frame / "jtframe_sh.v"),
        str(frame / "ram/jtframe_prom.v"),
    ], check=True)
    subprocess.run(["vvp", str(binary)], check=True, timeout=30)
