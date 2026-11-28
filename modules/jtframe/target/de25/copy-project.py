#!/usr/bin/env python3
"""Copy a generated DE25 project and its source files into release/."""
import argparse
import re
from pathlib import Path
from shutil import copy2, copytree

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("core", help="core name, e.g. gng")
args = parser.parse_args()

target = Path(__file__).resolve().parent
root = target.parents[3]
project = root / "cores" / args.core / "de25"
qip = project / "files.qip"
if not qip.is_file():
    parser.exit(1, f"Generate the project first with jtcore {args.core} -t de25\n")

qpf, = project.glob("*.qpf")
qsf = qpf.with_suffix(".qsf")
settings = qsf.read_text()
# A container may have generated the project under a different checkout path.
match = re.search(r'^set_global_assignment -name SEARCH_PATH "(.+)/modules/jtframe/hdl/inc"$',
                  settings, re.MULTILINE)
if not match:
    parser.exit(1, f"Regenerate {qsf.name} with jtcore {args.core} -t de25\n")
build_root = Path(match[1])
dest = root / "release" / (qpf.stem + "-de25")
dest.mkdir(parents=True, exist_ok=True)

# Keep the board layout and the generated game wrapper next to the QPF.
layout = [
    (project, Path(".")),
    (target / "hdl", Path(".")),
    (target / "syn", Path("constraints")),
    (root, Path("src")),
]
assignments = []
for line in qip.read_text().splitlines():
    command, name_flag, file_type, filename = line.split(maxsplit=3)
    source = root / Path(filename).relative_to(build_root)
    for directory, prefix in layout:
        if directory in source.parents:
            relative = prefix / source.relative_to(directory)
            break
    output = dest / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    copy2(source, output)
    assignments.append(f"{command} {name_flag} {file_type} [file join $::quartus(qip_path) {{{relative}}}]")

copytree(target / "hdl/sys", dest / "sys", dirs_exist_ok=True)
copytree(target / "syn/ip", dest / "ip", dirs_exist_ok=True)
(dest / "constraints").mkdir(exist_ok=True)
for script in (target / "syn").glob("*.tcl"):
    copy2(script, dest / "constraints")
(dest / "include").mkdir(exist_ok=True)
for pattern in ("*.inc", "*.vh", "jtframe_game_instance.v"):
    for header in (root / "modules/jtframe/hdl/inc").glob(pattern):
        copy2(header, dest / "include")
for header in (project.parent / "hdl").glob("*.vh"):
    output = dest / "src" / "cores" / args.core / "hdl" / header.name
    output.parent.mkdir(parents=True, exist_ok=True)
    copy2(header, output)
for pattern in ("*.hex", "*.bin", "*.inc", "*.vh"):
    for asset in project.glob(pattern):
        if asset.is_file():
            copy2(asset, dest / asset.name)

frame = build_root / "modules/jtframe"
settings = settings.replace(f'"{frame}/hdl/inc"', '"include"')
settings = settings.replace(f'"{frame}/target/de25/syn/', '"constraints/')
settings = settings.replace(f'"{build_root}/cores/{args.core}/hdl"', f'"src/cores/{args.core}/hdl"')
(dest / "files.qip").write_text("\n".join(assignments) + "\n")
(dest / qsf.name).write_text(settings)
copy2(qpf, dest)
copy2(target / "THIRD_PARTY_NOTICES.md", dest)
print(dest / qpf.name)
