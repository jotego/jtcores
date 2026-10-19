#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
    echo "Usage: $0 VENDOR.zip NEW_BUILD_DIR" >&2
    exit 2
fi
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(cd -- "$source_dir/../../../.." && pwd)
build_dir=$(realpath -m -- "$2")
[[ ! -e $build_dir ]] || { echo "Build directory must be new: $build_dir" >&2; exit 1; }
mkdir -p -- "$build_dir"
bash "$source_dir/build-vendor.sh" "$1" "$build_dir" prepare
generated="$build_dir/jttms10-generated"
bash "$repo_root/modules/jttms10/ver/build.sh" "$generated"
cp "$generated"/*.uc "$generated"/*.hex "$build_dir/"
mkdir -p "$build_dir/ip/jttms10_fpga_runner"
cp "$source_dir/ip/jttms10_fpga_runner/jttms10_fpga_runner_hw.tcl" \
   "$build_dir/ip/jttms10_fpga_runner/"
cp "$source_dir/jttms10_fpga_runner.v" "$build_dir/ip/jttms10_fpga_runner/"
cp "$repo_root/modules/jttms10/hdl/"*.v "$build_dir/ip/jttms10_fpga_runner/"
cp "$generated/"*.vh "$generated/"*.hex "$generated/"*.uc "$build_dir/ip/jttms10_fpga_runner/"

python3 - "$build_dir/QSYS_test_board.tcl" <<'PY'
from pathlib import Path
import re
import sys
p=Path(sys.argv[1])
s=p.read_text()
if "add_instance jttms10_runner" not in s:
    pll=re.search(r"add_instance hdmi_pll altera_pll 20\.1\n.*?(?=\nadd_instance hps altera_hps)",s,re.S)
    if not pll: raise SystemExit("could not find the board's altera_pll template")
    runner_pll=pll.group(0).replace("hdmi_pll", "runner_pll").replace("{148.48}", "{25.0}")
    if runner_pll == pll.group(0): raise SystemExit("could not set runner PLL output frequency")
    s=s.replace(pll.group(0), runner_pll+"\n\n"+pll.group(0), 1)
    # This is a CPU regression appliance, not a video build. The HDMI DMA is
    # the only F2H SDRAM master, and both the DMA and HDMI TX introduce unrelated
    # 100/148 MHz timing paths. Retain the HPS, LW bridge, SYSID and runner.
    # Removing the full instance parameter blocks and every HDMI connection
    # makes Platform Designer prune the unused video/F2H path rather than
    # waiving its timing constraints.
    lines=s.splitlines(keepends=True)
    filtered=[]
    skip_instance=False
    for line in lines:
        if re.match(r"add_instance hdmi(?:_|\s)", line):
            skip_instance=True
            continue
        if skip_instance and line.startswith("set_instance_parameter_value "):
            continue
        if skip_instance:
            skip_instance=False
        if "hdmi" in line:
            continue
        filtered.append(line)
    s="".join(filtered)
    marker="add_instance sysid altera_avalon_sysid_qsys 20.1\n"
    if marker not in s: raise SystemExit("could not find Qsys insertion point")
    s=s.replace(marker, marker + "\nadd_instance jttms10_runner jttms10_fpga_runner 1.0\n", 1)
    marker="add_connection hps.h2f_reset sysid.reset\n"
    if marker not in s: raise SystemExit("could not find reset connection point")
    s=s.replace(marker, marker + "\nadd_connection hps.h2f_reset jttms10_runner.reset_n\n"
                "add_connection hps.h2f_reset runner_pll.reset\n", 1)
    marker="add_connection hps.h2f_user1_clock sysid.clk\n"
    if marker not in s: raise SystemExit("could not find clock connection point")
    s=s.replace(marker, marker + "\nadd_connection hps.h2f_user1_clock runner_pll.refclk\n"
                "add_connection runner_pll.outclk0 jttms10_runner.clk\n", 1)
    marker="add_connection hps.h2f_lw_axi_master sysid.control_slave\n"
    if marker not in s: raise SystemExit("could not find Avalon connection point")
    extra=("\nadd_connection hps.h2f_lw_axi_master jttms10_runner.s0\n"
           "set_connection_parameter_value hps.h2f_lw_axi_master/jttms10_runner.s0 arbitrationPriority {1}\n"
           "set_connection_parameter_value hps.h2f_lw_axi_master/jttms10_runner.s0 baseAddress {0x00010840}\n"
           "lock_avalon_base_address jttms10_runner.s0\n"
           "set_connection_parameter_value hps.h2f_lw_axi_master/jttms10_runner.s0 defaultConnection {0}\n")
    s=s.replace(marker, extra+marker, 1)
    p.write_text(s)
PY

export JTCORES_SOURCE="$repo_root"
export JTTMS10_RUNNER_GEN="$generated"
qsys=/opt/intelFPGA_lite/20.1/quartus/sopc_builder/bin
cd "$build_dir"
timed() {
    local label=$1; shift
    /usr/bin/time -f 'seconds=%e\nexit_code=%x' -o "logs/runner-$label.time" \
        "$@" >"logs/runner-$label.log" 2>&1 || { tail -n 60 "logs/runner-$label.log" >&2; return 1; }
}
timed qsys-create "$qsys/qsys-script" \
    '--cmd=set ::args {5CSEMA5F31C8|Cyclone V|TEI0022_dual_IS43TR16256BL-125KBLI|no_project}' \
    "--script=$build_dir/QSYS_test_board.tcl" \
    "--search-path=$build_dir/ip/**/*,$"
timed qsys-generate "$qsys/qsys-generate" "$build_dir/QSYS_test_board.qsys" \
    --synthesis=VHDL -bsf "--search-path=$build_dir/**/*,$"
[[ -s QSYS_test_board/synthesis/QSYS_test_board.qip ]]
# Qsys emits a refreshed Block Symbol File. Keep the BDF symbol's exported
# board pins consistent with this regression-only system (which has no HDMI).
python3 - "$build_dir/test_board.bdf" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
lines=p.read_text().splitlines(keepends=True)
out=[]
i=0
removed=0
while i < len(lines):
    if lines[i].lstrip().startswith('(port'):
        block=[]
        depth=0
        while i < len(lines):
            line=lines[i]
            block.append(line)
            depth += line.count('(')-line.count(')')
            i += 1
            if depth == 0:
                break
        text=''.join(block)
        if 'hdmi_' in text:
            removed += 1
        else:
            out.extend(block)
    else:
        out.append(lines[i])
        i += 1
if removed != 5:
    raise SystemExit(f'expected five HDMI BDF symbol ports; removed {removed}')
p.write_text(''.join(out))
PY
python3 - "$build_dir/test_board.qsf" "$build_dir/ip/jttms10_fpga_runner" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
source_dir=Path(sys.argv[2])
s=p.read_text()
constraint_file=Path(sys.argv[1]).parent/'runner_clock.sdc'
constraint_file.write_text('derive_pll_clocks\nderive_clock_uncertainty\n')
for line in (
    'set_global_assignment -name VERILOG_MACRO JTTMS10_REGRESSION',
    'set_global_assignment -name PROJECT_IP_REGENERATION_POLICY NEVER_REGENERATE_IP',
    f'set_global_assignment -name SEARCH_PATH {sys.argv[2]}',
    f'set_global_assignment -name SDC_FILE {constraint_file}',
):
    if line not in s.splitlines():
        s=s.rstrip()+"\n"+line+"\n"
for source in sorted(source_dir.glob('*.v')):
    line=f'set_global_assignment -library "QSYS_test_board" -name VERILOG_FILE {source}'
    if line not in s.splitlines():
        s=s.rstrip()+"\n"+line+"\n"
p.write_text(s)
PY
touch .qsys-generated
# Bind the eventual receipt and RBF to an immutable record of every design
# input immediately before Quartus starts. Recheck these hashes after the
# compile so a generated-image receipt cannot identify a later source tree.
python3 - "$build_dir" "$repo_root" "$source_dir" <<'PY'
import hashlib
import json
from pathlib import Path
import subprocess
import sys
build, repo, source = map(Path, sys.argv[1:])
paths = set()
for pattern in ('*.v', '*.vh', '*.hex', '*.uc'):
    paths.update((build/'ip/jttms10_fpga_runner').glob(pattern))
    paths.update((build/'jttms10-generated').glob(pattern))
    paths.update(build.glob(pattern))
for pattern in ('*.v', '*.vh', '*.hex', '*.uc'):
    paths.update((repo/'modules/jttms10/hdl').glob(pattern))
    paths.update((repo/'modules/jttms10/ver/fpga').glob(pattern))
for name in ('QSYS_test_board.qsys', 'QSYS_test_board.sopcinfo', 'QSYS_test_board.tcl',
             'QSYS_test_board/synthesis/QSYS_test_board.qip', 'test_board.qsf',
             'test_board.bdf', 'runner_clock.sdc', 'test_board.qpf'):
    path=build/name
    if path.is_file(): paths.add(path)
for name in ('build-runner.sh', 'build-vendor.sh'):
    path=source/name
    if path.is_file(): paths.add(path)
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()
quartus='/opt/quartus_free/quartus_sh'
qsys='/opt/intelFPGA_lite/20.1/quartus/sopc_builder/bin/qsys-generate'
def version(path):
    p=subprocess.run([path, '--version'], capture_output=True, text=True)
    return (p.stdout+p.stderr).strip()
manifest={'format':'jttms10-fpga-build-inputs-v1',
          'files':{str(p.resolve()):digest(p) for p in sorted(paths)},
          'tools':{quartus:version(quartus),qsys:version(qsys)}}
(build/'build-input-manifest.pre.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
timed compile /opt/quartus_free/quartus_sh --flow compile test_board
python3 - "$build_dir" <<'PY'
import hashlib
import json
from pathlib import Path
import sys
build=Path(sys.argv[1])
pre_path=build/'build-input-manifest.pre.json'
pre=json.loads(pre_path.read_text())
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()
changed=[]
for filename,expected in pre['files'].items():
    path=Path(filename)
    actual=digest(path) if path.is_file() else None
    if actual!=expected:
        changed.append({'path':filename,'before':expected,'after':actual})
unexpected=[item['path'] for item in changed
            if Path(item['path']).name!='QSYS_test_board.sopcinfo']
if unexpected:
    raise SystemExit('unexpected Quartus input changes: '+', '.join(unexpected))
rbf=build/'output_files/test_board.rbf'
if not rbf.is_file(): raise SystemExit('Quartus compile did not produce an RBF')
flow=(build/'logs/runner-compile.time').read_text()
import re
seconds=re.search(r'seconds=([0-9.]+)',flow)
exitcode=re.search(r'exit_code=(\d+)',flow)
if not seconds or not exitcode or int(exitcode.group(1))!=0:
    raise SystemExit('Quartus flow did not terminate successfully')
compiled={}
for pattern in ('*.v','*.vh','*.qip'):
    for path in (build/'db/ip/QSYS_test_board').rglob(pattern):
        compiled[str(path.relative_to(build))]=digest(path)
sysid=build/'db/ip/QSYS_test_board/submodules/QSYS_test_board_sysid.v'
match=re.search(r'assign\s+readdata\s*=\s*address\s*\?\s*(\d+)\s*:\s*(\d+)\s*;',sysid.read_text())
if not match or int(match.group(2))!=22:
    raise SystemExit('compiled SYSID is missing or differs from expected ID 22')
post={'format':'jttms10-fpga-build-inputs-post-v1',
      'pre_manifest_sha256':digest(pre_path),
      'pre_compile_changed_files':changed,
      'quartus_generated_metadata_changes':[item for item in changed
          if Path(item['path']).name=='QSYS_test_board.sopcinfo'],
      'authoritative_source_hashes_unchanged':not unexpected,
      'compile_flow_exit':int(exitcode.group(1)),
      'compile_flow_seconds':float(seconds.group(1)),
      'compile_flow_time_sha256':digest(build/'logs/runner-compile.time'),
      'compile_flow_log_sha256':digest(build/'logs/runner-compile.log'),
      'sysid':int(match.group(2)),'sysid_timestamp':int(match.group(1)),
      'rbf_sha256':digest(rbf),'compiled_qsys_hdl_sha256':compiled}
(build/'build-input-manifest.post.json').write_text(json.dumps(post,indent=2)+'\n')
PY
