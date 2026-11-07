#!/usr/bin/env python3
"""Prove the manual inventory and timing gates reject deliberate mutations."""
from pathlib import Path
import csv
import os
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
ORACLE = HERE / "oracle.csv"
CHECKER = HERE / "check_inventory.py"
YAML = ROOT / "modules/jt680x/ucode/6805.yaml"


def reject_inventory(name, rows, expected):
    with tempfile.TemporaryDirectory(prefix=f"jt6805-{name}-") as tmp:
        candidate = Path(tmp) / "oracle.csv"
        candidate.write_text(rows)
        run = subprocess.run(
            [sys.executable, str(CHECKER), "--oracle", str(candidate), "--yaml", str(YAML)],
            cwd=HERE, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        if run.returncode == 0 or expected not in run.stdout:
            raise SystemExit(f"negative inventory control {name} escaped:\n{run.stdout}")
        print(f"NEGATIVE-CONTROL: {name} rejected: {expected}")


def stage_generated_headers(temp):
    """Stage generated includes so each mutant sim reads its private .uc file."""
    for name in ("6805.vh", "6805_param.vh"):
        shutil.copy2(HERE / name, temp / name)
    vh = temp / "6805.vh"
    text = vh.read_text().replace(
        "modules/jtframe/ver/cpu/jt6805_timing/6805.uc", "6805.uc"
    )
    vh.write_text(text)


with ORACLE.open(newline="") as stream:
    oracle_text = stream.read()
records = list(csv.reader(oracle_text.splitlines()))
reject_inventory("empty oracle", "", "manual inventory schema mismatch")
reject_inventory("truncated oracle", "\n".join(oracle_text.splitlines()[:-1]) + "\n", "row count manual/active")
reject_inventory("duplicate opcode", oracle_text + "\n" + ",".join(records[1]) + "\n", "duplicate manual opcode")
bad = [line.split(",") for line in oracle_text.splitlines()]
bad[1][3] = "not-a-cycle"
reject_inventory("malformed cycle", "\n".join(",".join(row) for row in bad) + "\n", "invalid manual inventory row")

if shutil.which("iverilog") is None or shutil.which("vvp") is None:
    raise SystemExit("negative timing control requires iverilog and vvp")
env = os.environ.copy()
env.setdefault("JTROOT", str(ROOT))
env.setdefault("JTFRAME", str(ROOT / "modules/jtframe"))
with tempfile.TemporaryDirectory(prefix="jt6805-mutated-timing-") as tmp:
    temp = Path(tmp)
    gather_text = (HERE / "gather.f").read_text()
    gather_text = gather_text.replace("$JTROOT", env["JTROOT"]).replace("$JTFRAME", env["JTFRAME"])
    gather = temp / "gather.f"
    gather.write_text(gather_text)
    stage_generated_headers(temp)
    sim = temp / "sim.vvp"
    sources = sorted(str(path) for path in HERE.glob("*.v"))
    sources += [str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative timing control build failed:\n{compile_run.stdout}")
    cases = (HERE / "manual_cases.hex").read_text().splitlines()
    found = False
    for index, line in enumerate(cases):
        if line.startswith("9D"):
            # Mutate both manual profiles for NOP from two E to three E.
            cases[index] = "9D133000"
            found = True
            break
    if not found:
        raise SystemExit("cannot find NOP in generated manual case table")
    (temp / "manual_cases.hex").write_text("\n".join(cases) + "\n")
    # The generated control include loads its sibling microcode file at run
    # time, so provide that generated input alongside the mutated oracle.
    shutil.copy2(HERE / "6805.uc", temp / "6805.uc")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if run.returncode == 0 or "HMOS-matches=236 expected=237" not in run.stdout or "assessment harness failure" not in run.stdout:
        raise SystemExit(f"mutated timing oracle escaped:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: tampering with NOP's manual timing oracle was rejected by the all-HMOS runtime gate")

with tempfile.TemporaryDirectory(prefix="jt6805-mutated-vector-") as tmp:
    temp = Path(tmp)
    gather = temp / "gather.f"
    gather.write_text(gather_text)
    stage_generated_headers(temp)
    source = (HERE / "test.v").read_text()
    correct = "set_bytes('h1ffb,vector_pc[7:0]);"
    mutated = "set_bytes('h1ffb,(vector_pc[7:0]^8'h01));"
    if correct not in source:
        raise SystemExit("cannot locate manual IRQ/TIRQ vector fixture for mutation")
    mutant_test = temp / "test_vector.v"
    mutant_test.write_text(source.replace(correct, mutated, 1))
    sim = temp / "sim_vector.vvp"
    sources = [str(path) for path in HERE.glob("*.v") if path.name != "test.v"]
    sources += [str(mutant_test), str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative vector control build failed:\n{compile_run.stdout}")
    shutil.copy2(HERE / "6805.uc", temp / "6805.uc")
    shutil.copy2(HERE / "manual_cases.hex", temp / "manual_cases.hex")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if run.returncode == 0 or "IRQ interrupt did not vector" not in run.stdout:
        raise SystemExit(f"mutated vector fixture escaped:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: mutating the IRQ vector-table byte was rejected by the service fixture")

with tempfile.TemporaryDirectory(prefix="jt6805-mutated-result-") as tmp:
    temp = Path(tmp)
    gather = temp / "gather.f"
    gather.write_text(gather_text)
    stage_generated_headers(temp)
    source = (HERE / "test.v").read_text()
    correct = "set_bytes(target+1,data_value);"
    mutated = "set_bytes(target+1,(data_value^8'h01));"
    if correct not in source:
        raise SystemExit("cannot locate immediate operand fixture for result mutation")
    mutant_test = temp / "test_result.v"
    mutant_test.write_text(source.replace(correct, mutated, 1))
    sim = temp / "sim_result.vvp"
    sources = [str(path) for path in HERE.glob("*.v") if path.name != "test.v"]
    sources += [str(mutant_test), str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative result control build failed:\n{compile_run.stdout}")
    shutil.copy2(HERE / "6805.uc", temp / "6805.uc")
    shutil.copy2(HERE / "manual_cases.hex", temp / "manual_cases.hex")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if run.returncode == 0 or "LDA result mismatch op=a6" not in run.stdout:
        raise SystemExit(f"mutated result fixture escaped:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: mutating the immediate operand was rejected by the LDA result check")

with tempfile.TemporaryDirectory(prefix="jt6805-mutated-address-") as tmp:
    temp = Path(tmp)
    gather = temp / "gather.f"
    gather.write_text(gather_text)
    stage_generated_headers(temp)
    source = (HERE / "test.v").read_text()
    correct = "13'h0120,13'h0020,8'ha6,1)"
    mutated = "13'h0020,13'h0120,8'ha6,1)"
    if correct not in source:
        raise SystemExit("cannot locate poisoned IX1 effective-address fixture")
    mutant_test = temp / "test_address.v"
    mutant_test.write_text(source.replace(correct, mutated, 1))
    sim = temp / "sim_address.vvp"
    sources = [str(path) for path in HERE.glob("*.v") if path.name != "test.v"]
    sources += [str(mutant_test), str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative address control build failed:\n{compile_run.stdout}")
    shutil.copy2(HERE / "6805.uc", temp / "6805.uc")
    shutil.copy2(HERE / "manual_cases.hex", temp / "manual_cases.hex")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if run.returncode == 0 or "address effect 1 op=e6" not in run.stdout:
        raise SystemExit(f"mutated effective-address fixture escaped:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: swapping IX1 effective/poison addresses was rejected by the bus/data effect gate")

with tempfile.TemporaryDirectory(prefix="jt6805-missing-hmos-slot-") as tmp:
    temp = Path(tmp)
    gather = temp / "gather.f"
    gather.write_text(gather_text)
    stage_generated_headers(temp)
    sim = temp / "sim_missing_slot.vvp"
    sources = sorted(str(path) for path in HERE.glob("*.v"))
    sources += [str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative missing-slot build failed:\n{compile_run.stdout}")
    words = (HERE / "6805.uc").read_text().splitlines()
    # stdira starts at uaddress 0x86. Replace its first intentional pad
    # (slot 2) with the following EA_LD+RET slot. The same EA action remains,
    # but the subroutine returns one enabled edge earlier.
    words[0x862] = words[0x863]
    (temp / "6805.uc").write_text("\n".join(words) + "\n")
    shutil.copy2(HERE / "manual_cases.hex", temp / "manual_cases.hex")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if run.returncode == 0 or "HMOS-matches=235" not in run.stdout:
        raise SystemExit(f"missing HMOS slot escaped strict timing gate:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: deleting one direct-store HMOS delay slot is rejected by the 237-outcome oracle")

with tempfile.TemporaryDirectory(prefix="jt6805-mutated-irq-latch-") as tmp:
    temp = Path(tmp)
    original_ctrl = ROOT / "modules/jt680x/hdl/jt6805_ctrl.v"
    source = original_ctrl.read_text()
    correct = "if( irq_rise ) irq_pending <= 1;"
    mutant = "if( 1'b0 ) irq_pending <= 1;"
    if correct not in source:
        raise SystemExit("cannot locate external IRQ request-latch assignment for mutation")
    mutated_ctrl = temp / "jt6805_ctrl.v"
    mutated_ctrl.write_text(source.replace(correct, mutant, 1))
    gather = temp / "gather.f"
    gather.write_text(gather_text.replace(str(original_ctrl), str(mutated_ctrl)))
    stage_generated_headers(temp)
    sim = temp / "sim_irq_latch.vvp"
    sources = sorted(str(path) for path in HERE.glob("*.v"))
    sources += [str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative IRQ-latch control build failed:\n{compile_run.stdout}")
    shutil.copy2(HERE / "6805.uc", temp / "6805.uc")
    shutil.copy2(HERE / "manual_cases.hex", temp / "manual_cases.hex")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if run.returncode == 0 or "masked IRQ edge was not retained until unmask" not in run.stdout:
        raise SystemExit(f"mutated IRQ request latch escaped:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: removing external IRQ edge capture was rejected by CLI/RTI masked-pulse fixtures")

with tempfile.TemporaryDirectory(prefix="jt6805-delayed-irq-acceptance-") as tmp:
    temp = Path(tmp)
    original_ctrl = ROOT / "modules/jt680x/hdl/jt6805_ctrl.v"
    source = original_ctrl.read_text()
    source = source.replace("reg  [2:0] iv_sel;", "reg  [2:0] iv_sel;\nreg        irq_skip;", 1)
    correct_ack = "wire       irq_ack  = cen & (ni | halt | stop) & irq_unmasked & irq_pending;"
    delayed_ack = """wire       irq_ack  = cen & (ni | halt | stop) & irq_unmasked & irq_pending & ~irq_skip;

always @(posedge clk, posedge rst) begin
    if( rst ) irq_skip <= 0;
    else if( irq_rise & i ) irq_skip <= 1;
    else if( cen & (ni | halt | stop) & irq_unmasked & irq_pending & irq_skip ) irq_skip <= 0;
end"""
    if correct_ack not in source:
        raise SystemExit("cannot locate IRQ acknowledgement for delayed-acceptance mutation")
    source = source.replace(correct_ack, delayed_ack, 1)
    correct_select = "if( irq_pending ) begin"
    delayed_select = "if( irq_pending & ~irq_skip ) begin"
    if correct_select not in source:
        raise SystemExit("cannot locate IRQ arbitration for delayed-acceptance mutation")
    source = source.replace(correct_select, delayed_select, 1)
    mutated_ctrl = temp / "jt6805_ctrl.v"
    mutated_ctrl.write_text(source)
    gather = temp / "gather.f"
    gather.write_text(gather_text.replace(str(original_ctrl), str(mutated_ctrl)))
    stage_generated_headers(temp)
    sim = temp / "sim_delayed_irq.vvp"
    sources = sorted(str(path) for path in HERE.glob("*.v"))
    sources += [str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative delayed-IRQ control build failed:\n{compile_run.stdout}")
    shutil.copy2(HERE / "6805.uc", temp / "6805.uc")
    shutil.copy2(HERE / "manual_cases.hex", temp / "manual_cases.hex")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if run.returncode == 0 or "masked IRQ service missed first eligible boundary" not in run.stdout:
        raise SystemExit(f"one-boundary-delayed IRQ mutant escaped:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: skipping the first eligible masked-IRQ boundary was rejected by saved-PC checks")

with tempfile.TemporaryDirectory(prefix="jt6805-sei-mask-boundary-") as tmp:
    temp = Path(tmp)
    original_ctrl = ROOT / "modules/jt680x/hdl/jt6805_ctrl.v"
    source = original_ctrl.read_text()
    correct = "wire       irq_unmasked = (ni && cc_sel==I0_CC) ? 1'b1 :\n                          (ni && cc_sel==I1_CC) ? 1'b0 : ~i;"
    mutant = "wire       irq_unmasked = ~i | (ni && cc_sel==I0_CC);"
    if correct not in source:
        raise SystemExit("cannot locate prospective-I interrupt-mask predicate for SEI mutation")
    mutated_ctrl = temp / "jt6805_ctrl.v"
    mutated_ctrl.write_text(source.replace(correct, mutant, 1))
    gather = temp / "gather.f"
    gather.write_text(gather_text.replace(str(original_ctrl), str(mutated_ctrl)))
    stage_generated_headers(temp)
    sim = temp / "sim_sei_mask.vvp"
    sources = sorted(str(path) for path in HERE.glob("*.v"))
    sources += [str(Path(env["JTFRAME"]) / "hdl/video/jtframe_vtimer.v"),
                str(Path(env["JTFRAME"]) / "hdl/ver/jtframe_test_clocks.v")]
    compile_run = subprocess.run(
        ["iverilog", "-g2012", *sources, f"-I{temp}", f"-I{env['JTFRAME']}/ver/inc", f"-f{gather}",
         "-s", "test", "-o", str(sim), "-D", "SIMULATION", "-D", "JTFRAME_MCLK=48000000"],
        cwd=temp, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if compile_run.returncode:
        raise SystemExit(f"negative SEI-mask control build failed:\n{compile_run.stdout}")
    shutil.copy2(HERE / "6805.uc", temp / "6805.uc")
    shutil.copy2(HERE / "manual_cases.hex", temp / "manual_cases.hex")
    run = subprocess.run(["vvp", str(sim)], cwd=temp, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    sei_rejected = (
        "IRQ accepted at SEI completion after I was set" in run.stdout or
        "SEI/CLI retained IRQ saved PCL=02, expected 04" in run.stdout
    )
    if run.returncode == 0 or not sei_rejected:
        raise SystemExit(f"unmasked-SEI mutant escaped the prospective-mask fixture:\n{run.stdout[-5000:]}")
    print("NEGATIVE-CONTROL: using old I on SEI's I1 completion edge was rejected by the SEI→NOP fixture")

print("PASS: inventory, timing-oracle, architectural-result, effective-address, vector, IRQ-latch, first-eligible-boundary, and SEI-mask negative controls")
