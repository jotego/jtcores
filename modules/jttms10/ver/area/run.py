#!/usr/bin/env python3
"""Isolated Quartus Cyclone V area measurement for the old NARC GSP or scalar CPU."""

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
MODULE = ROOT / "modules/jttms10"
REFERENCE = ROOT / "modules/tms34010"
DEVICE = "5CSEBA6U23I7"


def call(args, *, cwd=None, log=None):
    if log is None:
        return subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=True).stdout.strip()
    with log.open("w") as stream:
        subprocess.run(args, cwd=cwd, check=True, stdout=stream, stderr=subprocess.STDOUT)


def snapshot(source, target, hashes):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    hashes[str(source.relative_to(ROOT))] = hashlib.sha256(target.read_bytes()).hexdigest()
    return target


def qsf_path(path):
    # Quartus QSF's Tcl-like parser does not strip brace quoting for file assignments.
    return str(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--reference", action="store_true", help="old jtnarc_gsp boundary")
    mode.add_argument("--scalar", action="store_true", help="current incomplete jttms10 CPU alone")
    parser.add_argument("output", type=Path, help="new, empty output directory, preferably under /tmp")
    parser.add_argument("--quartus-bin", type=Path, default=Path("/opt/intelFPGA_lite/20.1/quartus/bin"))
    args = parser.parse_args()
    out = args.output.resolve()
    if any(ch.isspace() for ch in str(out)):
        parser.error("output path must not contain whitespace (Quartus QSF file assignments)")
    if out.exists() and any(out.iterdir()):
        parser.error(f"output directory is not empty: {out}")
    out.mkdir(parents=True, exist_ok=True)

    tool = args.quartus_bin.resolve()
    version = call([str(tool / "quartus_sh"), "--version"])
    hashes = {}
    sources = []
    qsf = [
        'set_global_assignment -name FAMILY "Cyclone V"',
        f"set_global_assignment -name DEVICE {DEVICE}",
        "set_global_assignment -name NUM_PARALLEL_PROCESSORS 4",
        'set_global_assignment -name OPTIMIZATION_MODE "HIGH PERFORMANCE EFFORT"',
        "set_global_assignment -name SEED 1",
    ]
    sdc = "create_clock -name clk -period 20.000 [get_ports clk]\nderive_clock_uncertainty\n"

    if args.reference:
        project, top = "reference", "jtnarc_gsp"
        rtl = REFERENCE / "rtl"
        selected = [rtl / "tms34010_pkg.sv"]
        selected += sorted(p for p in rtl.rglob("*.sv") if p.name != "tms34010_pkg.sv"
                           and "fpga" not in p.parts and p.name != "tms34010_pin_system.sv")
        selected += [ROOT / "cores/narc/hdl/jtnarc_vclk.v", ROOT / "cores/narc/hdl/jtnarc_gsp.sv"]
        for source in selected:
            target = snapshot(source, out / "src" / source.relative_to(ROOT), hashes)
            sources.append(("VERILOG_FILE" if source.suffix == ".v" else "SYSTEMVERILOG_FILE", target))
        exception = snapshot(REFERENCE / "fpga/tms34010_core.sdc", out / "tms34010_core.sdc", hashes)
        sdc += f"source {exception}\n"
        ports = ["rst", "clk", "lint1_n", "lint2_n", "cyc_req", "cyc_kind[*]",
                 "cyc_addr[*]", "cyc_wdata[*]", "cyc_io_rdata[*]", "cyc_iaq",
                 "cyc_srfaddr[*]", "cyc_dpytap[*]", "cyc_org", "cyc_rdata[*]",
                 "cyc_ack", "hs", "vs", "hblank", "vblank", "pc[*]"]
    else:
        project, top = "scalar", "jttms10"
        for source in sorted((MODULE / "hdl").glob("*.v")):
            target = snapshot(source, out / "src" / source.relative_to(ROOT), hashes)
            sources.append(("VERILOG_FILE", target))
        # Generate the same ROM/includes used in simulation, inside this snapshot.
        call(["bash", str(MODULE / "ver/build.sh"), str(out)], log=out / "ucode_build.log")
        for name in ("tms10.uc", "tms10.vh", "tms10_param.vh"):
            hashes[f"generated/{name}"] = hashlib.sha256((out / name).read_bytes()).hexdigest()
        hashes[str((MODULE / "ucode/tms10.yaml").relative_to(ROOT))] = hashlib.sha256(
            (MODULE / "ucode/tms10.yaml").read_bytes()).hexdigest()
        qsf.append(f"set_global_assignment -name SEARCH_PATH {qsf_path(out)}")
        ports = ["rst", "clk", "cen", "mem_req", "mem_we", "mem_iaq",
                 "mem_addr[*]", "mem_wdata[*]", "mem_size[*]", "mem_rdata[*]",
                 "mem_ack", "pc[*]", "st[*]", "ir[*]", "retire", "fault"]

    qsf += [f"set_global_assignment -name TOP_LEVEL_ENTITY {top}",
            f"set_global_assignment -name SDC_FILE {project}.sdc"]
    qsf += [f"set_global_assignment -name {kind} {qsf_path(path)}" for kind, path in sources]
    qsf += [f"set_instance_assignment -name VIRTUAL_PIN ON -to {port}" for port in ports]
    (out / f"{project}.qsf").write_text("\n".join(qsf) + "\n")
    (out / f"{project}.qpf").write_text(f'PROJECT_REVISION = "{project}"\n')
    (out / f"{project}.sdc").write_text(sdc)

    manifest = {
        "mode": project, "top": top, "device": DEVICE, "clock_ns": 20,
        "tool_version": version, "tool_bin": str(tool),
        "repo_commit": call(["git", "rev-parse", "HEAD"], cwd=ROOT),
        "old_module_commit": call(["git", "-C", str(REFERENCE), "rev-parse", "HEAD"]),
        "source_sha256": hashes,
        "scope": ("old NARC GSP with tied-off host/HOLD and VCLK enable"
                  if args.reference else "incomplete scalar CPU alone; excludes I/O, video, field sequencer, arbiter"),
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for phase in ("map", "fit"):
        print(f"{project}: quartus_{phase}", flush=True)
        call([str(tool / f"quartus_{phase}"), project,
              "--read_settings_files=on", "--write_settings_files=off"],
             cwd=out, log=out / f"{phase}.log")
    print(f"Reports: {out / (project + '.map.rpt')} and {out / (project + '.fit.rpt')}")


if __name__ == "__main__":
    main()
