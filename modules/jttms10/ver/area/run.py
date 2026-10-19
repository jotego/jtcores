#!/usr/bin/env python3
"""Isolated Quartus Cyclone V area measurement for GSP or microcoded CPU."""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
MODULE = ROOT / "modules/jttms10"
REFERENCE = ROOT / "modules/tms34010"
DEVICE = "5CSEBA6U23I7"
NARC_PORTS = ["rst", "clk", "lint1_n", "lint2_n", "cyc_req", "cyc_kind[*]",
              "cyc_addr[*]", "cyc_wdata[*]", "cyc_io_rdata[*]", "cyc_iaq",
              "cyc_srfaddr[*]", "cyc_dpytap[*]", "cyc_org", "cyc_rdata[*]",
              "cyc_ack", "hs", "vs", "hblank", "vblank", "pc[*]"]


def call(args, *, cwd=None, log=None, env=None):
    if log is None:
        return subprocess.run(args, cwd=cwd, env=env, check=True, text=True, capture_output=True).stdout.strip()
    with log.open("w") as stream:
        subprocess.run(args, cwd=cwd, env=env, check=True, stdout=stream, stderr=subprocess.STDOUT)


def snapshot(source, target, hashes, source_ref=None):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source_ref:
        target.write_bytes(subprocess.check_output(
            ["git", "show", f"{source_ref}:{source.relative_to(ROOT)}"], cwd=ROOT))
    else:
        shutil.copyfile(source, target)
    hashes[str(source.relative_to(ROOT))] = hashlib.sha256(target.read_bytes()).hexdigest()
    return target


def source_files(folder, pattern, source_ref):
    if not source_ref:
        return sorted(folder.glob(pattern))
    names = call(["git", "ls-tree", "-r", "--name-only", source_ref, "--",
                  str(folder.relative_to(ROOT))], cwd=ROOT).splitlines()
    return sorted(ROOT / name for name in names
                  if (ROOT / name).parent == folder and Path(name).match(pattern))


def reference_revisions(source_ref=None):
    pin = call(["git", "rev-parse", f"{source_ref or 'HEAD'}:modules/tms34010"], cwd=ROOT)
    # An uninitialized submodule is still inside the parent repository.
    # Running git there without checking its own marker reports the parent's
    # HEAD, which is not evidence of an old-CPU checkout.
    checkout = call(["git", "rev-parse", "HEAD"], cwd=REFERENCE) if (REFERENCE / ".git").exists() else None
    return pin, checkout


def qsf_path(path):
    # Quartus QSF's Tcl-like parser does not strip brace quoting for file assignments.
    return str(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--reference", action="store_true", help="old jtnarc_gsp boundary")
    mode.add_argument("--scalar", action="store_true", help="jttms10 CPU and graphics engine alone")
    mode.add_argument("--word", action="store_true", help="jttms10 plus physical-word field adapter")
    mode.add_argument("--fabric", action="store_true", help="peripheral I/O/video/refresh/bus/host fabric alone")
    mode.add_argument("--system", action="store_true", help="integrated CPU, field adapter and synchronous fabric")
    mode.add_argument("--narc", action="store_true", help="new CPU at the same tied-off NARC GSP boundary as reference")
    parser.add_argument("output", type=Path, help="new, empty output directory, preferably under /tmp")
    parser.add_argument("--quartus-bin", type=Path, default=Path("/opt/intelFPGA_lite/20.1/quartus/bin"))
    parser.add_argument("--source-ref", help="copy new CPU/NARC inputs from this git commit instead of live files")
    parser.add_argument("--snapshot-only", action="store_true",
                        help="capture and generate sources without starting Quartus")
    args = parser.parse_args()
    if args.source_ref and args.reference:
        parser.error("--source-ref applies to new CPU modes; reference uses the pinned old submodule")
    source_ref = (call(["git", "rev-parse", args.source_ref + "^{commit}"], cwd=ROOT)
                  if args.source_ref else None)
    reference_pin, reference_commit = reference_revisions(source_ref)
    if args.reference and reference_commit is None:
        parser.error("reference CPU submodule is not initialized; run git submodule update --init modules/tms34010")
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
        ports = NARC_PORTS
    elif args.fabric:
        project, top = "fabric", "jttms10_fabric"
        available={p.name for p in source_files(MODULE / "hdl","*.v",source_ref)}
        for name in ("jttms10_fabric.v", "jttms10_bus.v", "jttms10_io.v",
                     "jttms10_host.v", "jttms10_video.v", "jttms10_refresh.v", "jttms10_bus_timer.v"):
            if name=="jttms10_bus_timer.v" and name not in available:continue
            source = MODULE / "hdl" / name
            target = snapshot(source, out / "src" / source.relative_to(ROOT), hashes, source_ref)
            sources.append(("VERILOG_FILE", target))
        # Record the current instruction YAML snapshot for context even though
        # this standalone fabric has no CPU or generated microcode.
        for source in source_files(MODULE / "ucode", "*.yaml", source_ref):
            snapshot(source, out / "src" / source.relative_to(ROOT), hashes, source_ref)
        ports = ["clk", "rst", "vclk_cen", "hcs_n", "hsync_n", "vsync_n",
                 "lint1_n", "lint2_n", "hold_req", "hold_ack",
                 "host_req", "host_we", "host_reg[*]", "host_be[*]",
                 "host_wdata[*]", "host_rdata[*]", "host_ack", "host_busy",
                 "word_req",
                 "word_we", "word_iaq", "word_lock", "word_pixel",
                 "word_addr[*]", "word_wdata[*]", "word_rdata[*]",
                 "word_ack", "word_restart", "nmi_clear", "wvp_set",
                 "psize[*]", "convsp[*]", "convdp[*]", "control[*]",
                 "pmask[*]", "pixel_srt", "intenb[*]", "intpend[*]",
                 "hstctlh[*]", "irq_pending", "irq_vector[*]",
                 "nmi_pending", "nmi_nmim", "halt", "hint_n",
                 "hcount[*]", "vcount[*]", "dpyadr[*]", "refcnt[*]",
                 "hs", "vs", "hblank", "vblank", "blank",
                 "cyc_req", "cyc_kind[*]", "cyc_addr[*]", "cyc_wdata[*]",
                 "cyc_io_rdata[*]", "cyc_iaq", "cyc_srfaddr[*]",
                 "cyc_dpytap[*]", "cyc_org", "cyc_dram_row[*]",
                 "cyc_rdata[*]", "cyc_ack"]
    else:
        project, top = (("narc", "jtnarc_gsp") if args.narc else
                        ("system", "jttms10_system") if args.system else
                        ("word", "jttms10_word") if args.word else
                        ("scalar", "jttms10"))
        for source in source_files(MODULE / "hdl", "*.v", source_ref):
            target = snapshot(source, out / "src" / source.relative_to(ROOT), hashes, source_ref)
            sources.append(("VERILOG_FILE", target))
        for source in source_files(MODULE / "ucode", "*.yaml", source_ref):
            snapshot(source, out / "src" / source.relative_to(ROOT), hashes, source_ref)
        if args.narc:
            for name in ("jtnarc_gsp.sv", "jtnarc_vclk.v"):
                source = ROOT / "cores/narc/hdl" / name
                target = snapshot(source, out / "src" / source.relative_to(ROOT), hashes, source_ref)
                sources.append(("SYSTEMVERILOG_FILE" if source.suffix == ".sv" else "VERILOG_FILE", target))
            qsf.append("set_global_assignment -name VERILOG_MACRO JTNARC_UCODE=1")
        # Generate exclusively from the copied YAML, so the ROM and manifest
        # describe one immutable source snapshot even if the live tree changes.
        env = os.environ.copy()
        env["MODULES"] = str(out / "src/modules")
        env["JTFRAME"] = str(ROOT / "modules/jtframe")
        call([str(ROOT / "modules/jtframe/bin/jtframe"), "ucode", "--list",
              "--output", "tms10", "jttms10", "tms10"],
             cwd=out, log=out / "ucode_build.log", env=env)
        image_names = ["tms10.uc", "tms10.vh", "tms10_param.vh"]
        if (out / "src/modules/jttms10/ucode/gfx.yaml").exists():
            call([str(ROOT / "modules/jtframe/bin/jtframe"), "ucode", "--list",
                  "--output", "tms10_gfx", "jttms10", "gfx"],
                 cwd=out, log=out / "gfx_ucode_build.log", env=env)
            image_names.extend(("tms10_gfx.uc", "tms10_gfx.vh",
                                "tms10_gfx_param.vh"))
            checker_source = MODULE / "ver/gfx/check_targets.py"
            checker = snapshot(checker_source,
                               out / "src" / checker_source.relative_to(ROOT),
                               hashes, source_ref)
            call(["python3", str(checker),
                  str(out / "src/modules/jttms10/ucode/gfx.yaml"),
                  str(out / "tms10_gfx_param.vh"), str(out / "tms10_gfx.uc")],
                 cwd=out, log=out / "gfx_target_check.log")
            flow_source = MODULE / "ver/gfx/check_flow.py"
            flow = snapshot(flow_source,
                            out / "src" / flow_source.relative_to(ROOT),
                            hashes, source_ref)
            call(["python3", str(flow),
                  str(out / "src/modules/jttms10/ucode/gfx.yaml"),
                  "--engine", str(out / "src/modules/jttms10/hdl/jttms10_gfx.v")],
                 cwd=out, log=out / "gfx_flow_check.log")
        controller = out / "src/modules/jttms10/hdl/jttms10_ctrl.v"
        if "function automatic [7:0] decode_family" in controller.read_text():
            for relative in ("ver/decoder/generate.py", "ver/decoder/dump.sv",
                             "hdl/tms10_dispatch.hex"):
                snapshot(MODULE / relative,
                         out / "src/modules/jttms10" / relative, hashes, source_ref)
            generator = out / "src/modules/jttms10/ver/decoder/generate.py"
            image = out / "src/modules/jttms10/hdl/tms10_dispatch.hex"
            call(["python3", str(generator), str(controller), str(out),
                  "--check", str(image)],
                 cwd=out, log=out / "dispatch_build.log")
            image_names.append("tms10_dispatch.hex")
        for name in image_names:
            hashes[f"generated/{name}"] = hashlib.sha256((out / name).read_bytes()).hexdigest()
        qsf.append(f"set_global_assignment -name SEARCH_PATH {qsf_path(out)}")
        if args.narc:
            ports = NARC_PORTS
        elif args.system:
            ports = ["clk", "rst", "cen", "vclk_cen", "hcs_n", "hsync_n",
                     "vsync_n", "lint1_n", "lint2_n", "hold_req", "emu_run",
                     "hold_ack", "emu_ack", "host_req", "host_we",
                     "host_reg[*]", "host_be[*]", "host_wdata[*]",
                     "host_rdata[*]", "host_ack", "host_busy", "hint_n",
                     "hs", "vs", "hblank", "vblank", "blank", "cyc_req",
                     "cyc_kind[*]", "cyc_addr[*]", "cyc_wdata[*]",
                     "cyc_io_rdata[*]", "cyc_iaq", "cyc_srfaddr[*]",
                     "cyc_dpytap[*]", "cyc_org", "cyc_dram_row[*]",
                     "cyc_rdata[*]", "cyc_ack", "pc[*]", "st[*]",
                     "ir[*]", "retire", "fault", "intenb[*]", "intpend[*]",
                     "irq_pending", "nmi_pending", "halt"]
        elif args.word:
            ports = ["rst", "clk", "cen", "word_req", "word_we", "word_addr[*]",
                     "word_wdata[*]", "word_iaq", "word_lock", "word_pixel", "word_rdata[*]",
                     "word_ack", "word_restart", "irq_req", "irq_vector[*]",
                     "nmi_req", "nmi_nostack", "halt_req", "emu_run",
                     "psize[*]", "convsp[*]", "convdp[*]", "control[*]", "pmask[*]",
                     "pixel_srt", "cache_flush", "wvp_set",
                     "nmi_clear", "emu_ack", "pc[*]", "st[*]", "ir[*]",
                     "retire", "fault"]
        else:
            ports = ["rst", "clk", "cen", "mem_req", "mem_we", "mem_iaq", "mem_program", "mem_pixel",
                     "mem_addr[*]", "mem_wdata[*]", "mem_size[*]", "mem_rdata[*]",
                     "mem_ack", "irq_req", "irq_vector[*]", "nmi_req",
                     "nmi_nostack", "halt_req", "emu_run", "nmi_clear",
                     "psize[*]", "convsp[*]", "convdp[*]", "control[*]", "pmask[*]", "wvp_set",
                     "emu_ack", "pc[*]", "st[*]", "ir[*]", "retire", "fault"]

    # Retain complete standalone port boundaries while reproducing commits
    # that predate the cache-hit/pending-transaction metadata ports.
    if args.fabric or args.word:
        module_name="jttms10_fabric.v" if args.fabric else "jttms10_word.v"
        for metadata in ("word_pending","word_early"):
            if metadata in (out/"src/modules/jttms10/hdl"/module_name).read_text():
                ports.append(metadata)
    elif args.scalar:
        if "mem_cached" in (out/"src/modules/jttms10/hdl/jttms10.v").read_text():
            ports.append("mem_cached")

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
        "source_commit": source_ref,
        "old_module_pin": reference_pin,
        "old_module_commit": reference_commit,
        "source_sha256": hashes,
        "scope": ("old NARC GSP with tied-off host/HOLD and VCLK enable"
                  if args.reference else
                  "new NARC GSP with tied-off host/HOLD and VCLK enable; complete graphics engine; same board cycle-controller exclusion as reference"
                  if args.narc else
                  "standalone I/O, video, refresh, bus and synchronous host fabric; excludes CPU, field adapter, asynchronous physical host pins and graphics datapath"
                  if args.fabric else
                  "integrated CPU with graphics engine, field adapter/cache, I/O/video/refresh/bus and synchronous host; excludes asynchronous physical host pins and NARC timing controller"
                  if args.system else
                  "CPU with graphics engine plus physical-word field adapter/cache; excludes I/O, video, arbitration and NARC integration"
                  if args.word else
                  "CPU with graphics engine alone; excludes I/O, video, field adapter, arbitration and NARC integration"),
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if args.snapshot_only:
        print(f"Source snapshot: {out / 'manifest.json'}")
        return
    for phase in ("map", "fit"):
        print(f"{project}: quartus_{phase}", flush=True)
        call([str(tool / f"quartus_{phase}"), project,
              "--read_settings_files=on", "--write_settings_files=off"],
             cwd=out, log=out / f"{phase}.log")
    print(f"Reports: {out / (project + '.map.rpt')} and {out / (project + '.fit.rpt')}")


if __name__ == "__main__":
    main()
