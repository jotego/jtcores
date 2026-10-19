#!/usr/bin/env bash
set -euo pipefail

main() {
    parse_args "$@"
    validate_paths
    if [[ $stage == map ]]; then
        prepare_build
        regenerate_payload
        freeze_inputs
        run_map
        write_map_result
    elif [[ $stage == full ]]; then
        prepare_build
        regenerate_payload
        freeze_inputs
        verify_frozen_inputs
        capture_compile_inputs
        remove_stale_compile_outputs
        run_compile
        write_result
    elif [[ $stage == certify-map ]]; then
        write_map_result
    else
        verify_map_result
        verify_frozen_inputs
        capture_compile_inputs
        remove_stale_compile_outputs
        run_compile
        write_result
    fi
}

parse_args() {
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        echo "Usage: $0 BASE_BUILD_DIR NEW_BUILD_DIR [full|map|certify-map|compile]" >&2
        exit 2
    fi
    source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    repo_root=$(cd -- "$source_dir/../../../.." && pwd)
    base_dir=$(realpath -- "$1")
    build_dir=$(realpath -m -- "$2")
    stage=${3:-compile}
    [[ $stage == map || $stage == full || $stage == compile || $stage == certify-map ]] || {
        echo "stage must be full, map, certify-map, or compile" >&2; exit 2;
    }
}

validate_paths() {
    [[ -s $base_dir/QSYS_test_board/synthesis/QSYS_test_board.qip ]] || {
        echo "base build lacks generated QIP" >&2; exit 1;
    }
    if [[ $stage == map || $stage == full ]]; then
        [[ ! -e $build_dir ]] || { echo "new build directory must not exist: $build_dir" >&2; exit 1; }
    else
        [[ -s $build_dir/test_board.qsf && -s $build_dir/v2-build-inputs.json ]] || {
            echo "prepared map-stage build/manifest not found: $build_dir" >&2; exit 1;
        }
    fi
}

prepare_build() {
    cp -a --reflink=auto "$base_dir" "$build_dir"
    python3 - "$base_dir" "$build_dir" "$repo_root" <<'PY'
from pathlib import Path
import sys
base, build, repo = map(Path, sys.argv[1:])
old, new = str(base), str(build)
qsf = build / 'test_board.qsf'
s = qsf.read_text()
if s.count(old) < 1:
    raise SystemExit('project does not point at the supplied base build path')
s = s.replace(old, new)
old_qsys = 'set_global_assignment -name QSYS_FILE QSYS_test_board.qsys'
new_qip = 'set_global_assignment -name QIP_FILE QSYS_test_board/synthesis/QSYS_test_board.qip'
if s.count(old_qsys) == 1:
    s = s.replace(old_qsys, new_qip)
elif s.count(new_qip) == 1:
    pass  # QIP-based base already uses the preserved generated Platform Designer system.
else:
    raise SystemExit('expected exactly one QSYS_FILE or preserved QIP_FILE assignment')
qsf.write_text(s)

for stale in ('v2-build-inputs.json','v2-build-result.json','v2-map-result.json',
              'v2-compile-inputs.json','build-input-manifest.post.json'):
    (build/stale).unlink(missing_ok=True)

ip = build / 'ip/jttms10_fpga_runner'
source_hdl = repo / 'modules/jttms10/hdl'
source_verilog = {p.name for p in source_hdl.glob('*.v')}
package_verilog = {p.name for p in ip.glob('*.v') if p.name != 'jttms10_fpga_runner.v'}
if source_verilog != package_verilog:
    raise SystemExit(f'CPU HDL file set changed: source={sorted(source_verilog)}, package={sorted(package_verilog)}')
for path in source_hdl.glob('*.v'):
    (ip / path.name).write_bytes(path.read_bytes())
(ip / 'jttms10_fpga_runner.v').write_bytes(
    (repo / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v').read_bytes())
PY
}

regenerate_payload() {
    local generated_tmp
    generated_tmp=$(mktemp -d "${TMPDIR:-/tmp}/jttms10-runner-generated.XXXXXX")
    trap 'rm -rf -- "$generated_tmp"' RETURN
    bash "$repo_root/modules/jttms10/ver/build.sh" "$generated_tmp"
    python3 - "$build_dir" "$generated_tmp" <<'PY'
from pathlib import Path
import sys
build, generated = map(Path, sys.argv[1:])
package = build / 'ip/jttms10_fpga_runner'
generated_root = build/'jttms10-generated'
roots = (package, build)
extensions = ('.uc', '.hex', '.vh')
files = {p.name:p for p in generated.iterdir() if p.is_file() and p.suffix in extensions}
if not files:
    raise SystemExit('ucode build produced no payload files')
if generated_root.exists():
    import shutil
    shutil.rmtree(generated_root)
shutil.copytree(generated, generated_root)
for root in roots:
    root.mkdir(parents=True, exist_ok=True)
    for old in root.iterdir():
        generated_name = old.name.startswith('tms10')
        if old.is_file() and old.suffix in extensions and generated_name and old.name not in files:
            old.unlink()
    for name, source in files.items():
        (root/name).write_bytes(source.read_bytes())
for name, source in files.items():
    for root in (generated_root, *roots):
        if (root/name).read_bytes() != source.read_bytes():
            raise SystemExit(f'generated payload copy mismatch: {name} in {root}')
PY
    rm -rf -- "$generated_tmp"
    trap - RETURN
}

remove_stale_compile_outputs() {
    local rbf="$build_dir/output_files/test_board.rbf"
    [[ -d "$build_dir/output_files" ]] || { echo "missing output_files directory" >&2; exit 1; }
    rm -f -- "$rbf" "$build_dir/v2-build-result.json" \
        "$build_dir/build-input-manifest.post.json"
    [[ ! -e $rbf ]] || { echo "stale RBF remains before compile" >&2; exit 1; }
}

freeze_inputs() {
    mkdir -p "$build_dir/logs"
    python3 - "$build_dir" "$repo_root" "$source_dir" "$base_dir" <<'PY'
from pathlib import Path
import hashlib, json, subprocess, sys
build, repo, source, base = map(Path, sys.argv[1:])
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024), b''): h.update(block)
    return h.hexdigest()
source_roots=(repo/'modules/jttms10/ucode',repo/'modules/jttms10/ver/decoder',
              repo/'modules/jttms10/ver/gfx',repo/'modules/jttms10/hdl',
              repo/'modules/jtframe/src/jtframe/ucode')
source_files={repo/'modules/jttms10/ver/build.sh', repo/'modules/jtframe/bin/jtframe'}
for root in source_roots:
    source_files.update(p for p in root.rglob('*') if p.is_file())
source_hashes={str(p):digest(p) for p in sorted(source_files)
               if p.is_file() and p.suffix != '.pyc' and '__pycache__' not in p.parts}
inputs=[build/'test_board.qsf',build/'test_board.qpf',build/'test_board.bdf',
        build/'QSYS_test_board.qsys',build/'QSYS_test_board.tcl',build/'QSYS_test_board.sopcinfo',
        build/'runner_clock.sdc',build/'QSYS_test_board/synthesis/QSYS_test_board.qip']
inputs += [p for p in build.iterdir() if p.is_file() and p.suffix.lower() in ('.v','.vh','.hex','.uc')]
inputs += [p for root in (build/'ip/jttms10_fpga_runner',build/'jttms10-generated')
           for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.v','.vh','.hex','.uc')]
inputs += [p for p in (build/'jttms10-generated').rglob('*') if p.is_file()]
inputs += [p for p in (build/'QSYS_test_board/synthesis').rglob('*') if p.is_file()]
inputs=sorted(set(p for p in inputs if p.is_file()))
quartus='/opt/quartus_free/quartus_sh'
version=subprocess.run([quartus,'--version'],capture_output=True,text=True)
manifest={'format':'jttms10-incremental-build-inputs-v2','base_build':str(base),
          'source_hashes':source_hashes,'files':{str(p):digest(p) for p in inputs},
          'quartus_version':(version.stdout+version.stderr).strip()}
(build/'v2-build-inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
}

verify_frozen_inputs() {
    python3 - "$build_dir" "$repo_root" <<'PY'
from pathlib import Path
import hashlib,json,sys
build,repo=map(Path,sys.argv[1:])
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
manifest=json.loads((build/'v2-build-inputs.json').read_text())
for path,expected in manifest['source_hashes'].items():
    p=Path(path)
    if not p.is_file() or digest(p)!=expected:
        raise SystemExit(f'authoritative source/generator changed since map stage: {path}')
for path,expected in manifest['files'].items():
    p=Path(path)
    if p.name.endswith('.sopcinfo'):
        continue # Platform Designer may rewrite generated metadata during map.
    if not p.is_file() or digest(p)!=expected:
        raise SystemExit(f'build input changed since map stage: {path}')
PY
}

capture_compile_inputs() {
    python3 - "$build_dir" <<'PY'
from pathlib import Path
import hashlib,json,sys
b=Path(sys.argv[1]); path=b/'v2-build-inputs.json'
m=json.loads(path.read_text())
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
files={name:digest(Path(name)) for name in m['files'] if Path(name).is_file()}
if len(files)!=len(m['files']): raise SystemExit('a build input disappeared before compile')
deltas=[]
for name,old in m['files'].items():
    if files[name]!=old:
        if Path(name).name.endswith('.sopcinfo'):
            deltas.append({'path':name,'pre_map_sha256':old,'compile_sha256':files[name]})
        else: raise SystemExit(f'non-generated input changed after map: {name}')
r={'format':'jttms10-compile-inputs-v1','map_manifest_sha256':digest(path),
   'files':files,'pre_map_metadata_deltas':deltas}
(b/'v2-compile-inputs.json').write_text(json.dumps(r,indent=2)+'\n')
PY
}

run_map() {
    cd "$build_dir"
    /usr/bin/time -f 'seconds=%e\nexit_code=%x' -o logs/v2-map.time \
        /opt/quartus_free/quartus_map --read_settings_files=on --write_settings_files=off \
        test_board -c test_board > logs/v2-map.log 2>&1
}

write_map_result() {
    python3 - "$build_dir" <<'PY'
from pathlib import Path
import hashlib,json,re,sys
b=Path(sys.argv[1])
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
t=(b/'logs/v2-map.time').read_text()
secs=re.search(r'seconds=([0-9.]+)',t); code=re.search(r'exit_code=(\d+)',t)
if not secs or not code or int(code.group(1))!=0: raise SystemExit('map command did not exit successfully')
log=(b/'logs/v2-map.log').read_text(errors='replace')
markers=('Quartus Prime Analysis & Synthesis was successful','Analysis & Synthesis was successful')
marker=next((x for x in markers if x in log),None)
if marker is None: raise SystemExit('map log lacks successful Analysis & Synthesis terminal marker')
manifest=b/'v2-build-inputs.json'
r={'format':'jttms10-incremental-map-result-v1','input_manifest_sha256':sha(manifest),
   'flow_exit_code':int(code.group(1)),'flow_seconds':float(secs.group(1)),
   'flow_log_sha256':sha(b/'logs/v2-map.log'),'terminal_marker':marker}
(b/'v2-map-result.json').write_text(json.dumps(r,indent=2)+'\n')
PY
}

verify_map_result() {
    python3 - "$build_dir" <<'PY'
from pathlib import Path
import hashlib,json,sys
b=Path(sys.argv[1]); m=b/'v2-build-inputs.json'; r=b/'v2-map-result.json'
if not r.is_file(): raise SystemExit('map lacks successful terminal result certificate')
x=json.loads(r.read_text())
if x.get('input_manifest_sha256')!=hashlib.sha256(m.read_bytes()).hexdigest() or \
   x.get('flow_exit_code')!=0 or not x.get('terminal_marker'):
    raise SystemExit('map result does not certify this frozen input set')
PY
}

run_compile() {
    cd "$build_dir"
    /usr/bin/time -f 'seconds=%e\nexit_code=%x' -o logs/v2-compile.time \
        /opt/quartus_free/quartus_sh --flow compile test_board > logs/v2-compile.log 2>&1
}

write_result() {
    python3 - "$build_dir" <<'PY'
from pathlib import Path
import hashlib,json,re,sys
b=Path(sys.argv[1])
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
inputs=json.loads((b/'v2-compile-inputs.json').read_text())
changed=[]
for name,expected in inputs['files'].items():
    p=Path(name); actual=sha(p) if p.is_file() else None
    if actual != expected: changed.append({'path':name,'before':expected,'after':actual})
if changed:
    raise SystemExit('input files changed during compile: '+', '.join(x['path'] for x in changed))
time=(b/'logs/v2-compile.time').read_text()
secs=re.search(r'seconds=([0-9.]+)',time); code=re.search(r'exit_code=(\d+)',time)
if not secs or not code or int(code.group(1)) != 0:
    raise SystemExit('Quartus flow did not finish successfully')
log=(b/'logs/v2-compile.log').read_text(errors='replace')
terminal_markers=('Quartus Prime Full Compilation was successful', 'Flow Status : Successful')
marker=next((item for item in terminal_markers if item in log), None)
if marker is None:
    raise SystemExit('Quartus log lacks a successful full-compilation terminal marker')
rbf=b/'output_files/test_board.rbf'
if not rbf.is_file(): raise SystemExit('Quartus produced no RBF')
post={'format':'jttms10-incremental-build-result-v1',
      'input_manifest_sha256':sha(b/'v2-build-inputs.json'),
      'compile_inputs_sha256':sha(b/'v2-compile-inputs.json'),
      'pre_map_metadata_deltas':inputs['pre_map_metadata_deltas'],
      'full_flow_only':not (b/'v2-map-result.json').is_file(),
      'flow_exit_code':int(code.group(1)),'flow_seconds':float(secs.group(1)),
      'flow_log_sha256':sha(b/'logs/v2-compile.log'),'rbf_sha256':sha(rbf),
      'terminal_marker':marker,
      'inputs_unchanged':True}
(b/'v2-build-result.json').write_text(json.dumps(post,indent=2)+'\n')
PY
}

main "$@"
