#!/usr/bin/env bash
set -euo pipefail

main() {
    parse_args "$@"
    validate_paths
    if [[ $stage == rapid ]]; then
        snapshot_rapid_parent
        prepare_build
        printf '%s\n' "$rapid_parent_json" > "$build_dir/v2-rapid-parent.json"
        regenerate_payload
        freeze_inputs
        verify_frozen_inputs
        remove_stale_compile_outputs
        capture_compile_inputs
        run_rapid
        verify_frozen_inputs
        write_rapid_result
    elif [[ $stage == partition-seed ]]; then
        snapshot_rapid_parent
        prepare_build
        printf '%s\n' "$rapid_parent_json" > "$build_dir/v2-partition-parent.json"
        configure_partition seed
        regenerate_payload
        run_partition_query seed
        freeze_inputs
        write_partition_source_delta seed
        verify_frozen_inputs
        remove_stale_compile_outputs
        capture_compile_inputs
        run_compile
        verify_frozen_inputs
        write_result
        write_partition_result seed
    elif [[ $stage == partition-update-microcode ]]; then
        snapshot_rapid_parent
        validate_partition_seed_parent
        prepare_build
        printf '%s\n' "$rapid_parent_json" > "$build_dir/v2-partition-parent.json"
        configure_partition microcode-update
        regenerate_payload
        run_partition_query microcode-update
        freeze_inputs
        write_partition_source_delta microcode-update
        verify_frozen_inputs
        remove_stale_compile_outputs
        capture_compile_inputs
        run_compile
        verify_frozen_inputs
        write_result
        write_partition_result microcode-update
    elif [[ $stage == partition-update ]]; then
        snapshot_rapid_parent
        validate_partition_seed_parent
        prepare_build
        printf '%s\n' "$rapid_parent_json" > "$build_dir/v2-partition-parent.json"
        configure_partition update
        regenerate_payload
        run_partition_query update
        freeze_inputs
        write_partition_source_delta update
        verify_frozen_inputs
        remove_stale_compile_outputs
        capture_compile_inputs
        run_compile
        verify_frozen_inputs
        write_result
        write_partition_result update
    elif [[ $stage == map ]]; then
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
        echo "Usage: $0 BASE_BUILD_DIR NEW_BUILD_DIR [rapid|full|map|certify-map|compile|partition-seed|partition-update|partition-update-microcode]" >&2
        exit 2
    fi
    source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    repo_root=$(cd -- "$source_dir/../../../.." && pwd)
    base_dir=$(realpath -- "$1")
    build_dir=$(realpath -m -- "$2")
    stage=${3:-compile}
    [[ $stage == rapid || $stage == map || $stage == full || $stage == compile || $stage == certify-map || $stage == partition-seed || $stage == partition-update || $stage == partition-update-microcode ]] || {
        echo "stage must be rapid, full, map, certify-map, compile, partition-seed, partition-update, or partition-update-microcode" >&2; exit 2;
    }
}

validate_paths() {
    case "$build_dir/" in
        "$base_dir/"*) echo "candidate must be outside its immutable parent" >&2; exit 1;;
    esac
    [[ -s $base_dir/QSYS_test_board/synthesis/QSYS_test_board.qip ]] || {
        echo "base build lacks generated QIP" >&2; exit 1;
    }
    if [[ $stage == rapid || $stage == map || $stage == full || $stage == partition-seed || $stage == partition-update || $stage == partition-update-microcode ]]; then
        [[ ! -e $build_dir ]] || { echo "new build directory must not exist: $build_dir" >&2; exit 1; }
    else
        [[ -s $build_dir/test_board.qsf && -s $build_dir/v2-build-inputs.json ]] || {
            echo "prepared map-stage build/manifest not found: $build_dir" >&2; exit 1;
        }
    fi
}

configure_partition() {
    local mode=$1
    python3 "$source_dir/partition_build.py" configure \
        --qsf "$build_dir/test_board.qsf" --mode "$mode" \
        --metadata "$build_dir/v2-partition-stage-precompile.json"
    python3 "$source_dir/partition_build.py" write-query --mode "$mode" \
        --output "$build_dir/v2-partition-query.tcl"
    python3 - "$build_dir" "$mode" "$base_dir" <<'PY'
from pathlib import Path
import hashlib,json,re,sys
b=Path(sys.argv[1]); mode=sys.argv[2]; parent=Path(sys.argv[3]).resolve()
config_path=b/'v2-partition-stage-precompile.json'
config=json.loads(config_path.read_text())
parent_result=parent/'v2-build-result.json'
config.update(parent_build_dir=str(parent),
    parent_build_result_sha256=hashlib.sha256(parent_result.read_bytes()).hexdigest(),
    parent_inputs_sha256=hashlib.sha256((parent/'v2-build-inputs.json').read_bytes()).hexdigest(),
    parent_image_sha256=hashlib.sha256((parent/'output_files/test_board.rbf').read_bytes()).hexdigest(),
    parent_sta_summary_sha256=hashlib.sha256((parent/'output_files/test_board.sta.summary').read_bytes()).hexdigest())
if mode in ('update','microcode-update'):
    p=parent/'v2-partition-stage-result.json'
    if not p.is_file(): raise SystemExit('partition update parent certificate disappeared')
    config['parent_partition_stage_sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
config_path.write_text(json.dumps(config,indent=2,sort_keys=True)+'\n')
PY
}

validate_partition_seed_parent() {
    # Run the complete common receipt checks and then require an intact seed certificate.
    python3 - "$base_dir" "$source_dir" <<'PY'
from pathlib import Path
import json,sys
b,source=map(Path,sys.argv[1:]); sys.path.insert(0,str(source))
import partition_build
from write_programming_receipt import validate_positive_sta
result=json.loads((b/'v2-build-result.json').read_text())
try: cert=partition_build.validate_partition_result(b,result)
except (ValueError,KeyError,OSError) as error: raise SystemExit(str(error))
if cert.get('mode')!='seed': raise SystemExit('partition update parent must be a seed result')
validate_positive_sta(b/'output_files/test_board.sta.summary')
parent=json.loads((b/'v2-partition-stage-precompile.json').read_text())
if parent.get('cpu_netlist')!='SOURCE' or parent.get('top_netlist')!='SOURCE':
    raise SystemExit('partition seed was not compiled SOURCE/SOURCE')
PY
}

run_partition_query() {
    local mode=$1
    mkdir -p "$build_dir/logs"
    (cd "$build_dir" && /opt/quartus_free/quartus_sh -t v2-partition-query.tcl) \
        > "$build_dir/logs/v2-partition-query.log" 2>&1 || {
            cat "$build_dir/logs/v2-partition-query.log" >&2
            echo "Quartus did not recognize the requested $mode CPU partition" >&2
            exit 1
        }
    python3 "$source_dir/partition_build.py" validate-query \
        --mode "$mode" --log "$build_dir/logs/v2-partition-query.log"
}

write_partition_source_delta() {
    local mode=$1
    python3 - "$base_dir" "$build_dir" "$mode" "$source_dir" <<'PY'
from pathlib import Path
import json,sys
base,build=map(Path,sys.argv[1:3]); mode=sys.argv[3]; source_dir=Path(sys.argv[4])
sys.path.insert(0,str(source_dir))
import partition_build
current=json.loads((build/'v2-build-inputs.json').read_text())
now=partition_build.source_hashes_relative(current)
if mode=='seed':
    delta=[]; before={}; input_delta={}; transient_input_delta={}
    payload_delta={}
    seed_payloads=partition_build.validate_generated_payload_manifest(
        build, Path(current['source_root']), verify_generation=True)
    partition_build.validate_dispatch_rom_source(Path(current['source_root']),seed_payloads)
    diagnostic_output_delta=partition_build.compare_non_compile_generated_outputs(base,build)
else:
    old_manifest=json.loads((base/'v2-build-inputs.json').read_text())
    before=partition_build.source_hashes_relative(old_manifest)
    try:
        if mode=='microcode-update':
            delta=partition_build.compute_cpu_microcode_source_delta(old_manifest,current)
            parent_root=Path(old_manifest['source_root'])
            candidate_root=Path(current['source_root'])
            parent_payloads=partition_build.validate_generated_payload_manifest(
                base, parent_root, verify_generation=True)
            candidate_payloads=partition_build.validate_generated_payload_manifest(
                build, candidate_root, verify_generation=True)
            partition_build.validate_dispatch_rom_source(parent_root,parent_payloads)
            partition_build.validate_dispatch_rom_source(candidate_root,candidate_payloads)
            payload_delta=partition_build.generated_payload_delta(base,build)
        else:
            delta=partition_build.compute_cpu_source_delta(old_manifest,current)
            payload_delta={}
        input_delta,transient_input_delta,diagnostic_output_delta=partition_build.validate_compiled_input_deltas(
            base,build,delta,payload_delta if mode=='microcode-update' else None,
            allow_generated_diagnostic_delta=mode=='microcode-update')
    except ValueError as error:
        raise SystemExit(str(error)) from error
row={'mode':mode,'source_delta':delta,'parent_source_hashes':before,'source_hashes':now,
     'compiled_input_delta':input_delta,
     'transient_compiled_input_delta':transient_input_delta,
     'non_compile_generated_output_delta':diagnostic_output_delta,
     'generated_payload_delta':payload_delta}
(build/'v2-partition-source-delta.json').write_text(json.dumps(row,indent=2,sort_keys=True)+'\n')
PY
}

write_partition_result() {
    local mode=$1
    python3 - "$build_dir" "$source_dir" "$mode" <<'PY'
from pathlib import Path
import hashlib,json,re,sys
b,source=map(Path,sys.argv[1:3]); mode=sys.argv[3]
sys.path.insert(0,str(source))
import partition_build
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
result_path=b/'v2-build-result.json'; result=json.loads(result_path.read_text())
if result.get('flow_exit_code')!=0 or result.get('full_flow_only') is not True:
    raise SystemExit('explicit partition experiment requires successful full compile flow')
log=b/'logs/v2-compile.log'; marker=result.get('terminal_marker')
if not marker or 'Full Compilation' not in marker:
    raise SystemExit('partition stage did not use a successful full Compilation terminal')
reports={name:b/f'output_files/test_board.{name}.rpt' for name in ('map','fit','asm','sta')}
if any(not path.is_file() for path in reports.values()):
    raise SystemExit('partition compile lacks fresh map/fit/asm/sta reports')
compile_time=b/'logs/v2-compile.time'
time_text=compile_time.read_text()
time_match=re.search(r'seconds=([0-9.]+)',time_text)
exit_match=re.search(r'exit_code=(\d+)',time_text)
if not time_match or not exit_match or int(exit_match.group(1)) != 0:
    raise SystemExit('partition compile timing record does not show exit 0')
cfg=json.loads((b/'v2-partition-stage-precompile.json').read_text())
delta=json.loads((b/'v2-partition-source-delta.json').read_text())
if result.get('flow_seconds') != float(time_match.group(1)):
    raise SystemExit('common build certificate flow time differs from compile timing record')
format_name = (partition_build.MICROCODE_RESULT_FORMAT
               if mode == 'microcode-update' else partition_build.RESULT_FORMAT)
cert={
 'format':format_name,'mode':mode,
 'command':['/opt/quartus_free/quartus_sh','--flow','compile','test_board'],
 'working_directory':str(b),'flow_exit_code':0,'inputs_unchanged':True,
 'flow_log_sha256':sha(log),'terminal_marker':marker,
 'compile_time_sha256':sha(compile_time),
 'flow_seconds':float(time_match.group(1)),
 'input_manifest_sha256':sha(b/'v2-build-inputs.json'),
 'compile_inputs_sha256':sha(b/'v2-compile-inputs.json'),
 'partition_config_sha256':sha(b/'v2-partition-stage-precompile.json'),
 'partition_query_log_sha256':sha(b/'logs/v2-partition-query.log'),
 'source_delta_sha256':sha(b/'v2-partition-source-delta.json'),
 'compiled_input_delta':delta['compiled_input_delta'],
 'transient_compiled_input_delta':delta.get('transient_compiled_input_delta',{}),
 'non_compile_generated_output_delta':delta.get('non_compile_generated_output_delta',{}),
 'partition_observations':partition_build.extract_partition_observations(b),
 'qsf_sha256':sha(b/'test_board.qsf'),'rbf_sha256':sha(b/'output_files/test_board.rbf'),
 'stage_reports':{name:sha(path) for name,path in reports.items()},
 'partitions':{'Top':{'root':'|','netlist':'Source File' if mode=='seed' else 'Post-Fit',
                      'preservation':'Placement and Routing'},
               'CPU':{'root':partition_build.CPU_ROOT,'netlist':'Source File',
                      'preservation':'Placement and Routing'}},
 'parent_build_dir':cfg['parent_build_dir'],
 'parent_build_result_sha256':cfg['parent_build_result_sha256'],
 'parent_inputs_sha256':cfg['parent_inputs_sha256'],
 'parent_image_sha256':cfg['parent_image_sha256'],
 'parent_sta_summary_sha256':cfg['parent_sta_summary_sha256'],
 'parent_partition_stage_sha256':cfg.get('parent_partition_stage_sha256'),
 'source_hashes':delta['source_hashes'],'source_delta':delta['source_delta'],
 'generated_payload_delta':delta.get('generated_payload_delta',{}),
 'generated_payload_manifest_sha256':
     sha(b/'v2-generated-payloads.json') if (b/'v2-generated-payloads.json').is_file() else None,
 'seed_package_reconstruction_sha256':
     partition_build.seed_package_reconstruction_binding(b, mode),
 'quartus_preflight':{'query_tcl_sha256':sha(b/'v2-partition-query.tcl'),
                      'query_log_sha256':sha(b/'logs/v2-partition-query.log')}}
cert_path=b/'v2-partition-stage-result.json'
cert_path.write_text(json.dumps(cert,indent=2,sort_keys=True)+'\n')
result.update(partition_mode=mode,partition_stage_sha256=sha(cert_path),
              flow_kind='explicit-cpu-partition-'+mode)
result_path.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
try: partition_build.validate_partition_result(b,result)
except (ValueError,KeyError,OSError) as error: raise SystemExit(str(error))
PY
}

snapshot_rapid_parent() {
    rapid_parent_json=$(python3 - "$base_dir" "$source_dir" <<'PY'
from pathlib import Path
import json,sys
parent,source=map(Path,sys.argv[1:])
sys.path.insert(0,str(source))
from write_programming_receipt import RAPID_RESULT_FORMAT,sha256,validate_positive_sta,validate_rapid_result
paths={'parent_build_result_sha256':parent/'v2-build-result.json',
       'parent_inputs_sha256':parent/'v2-build-inputs.json',
       'parent_image_sha256':parent/'output_files/test_board.rbf',
       'parent_sta_summary_sha256':parent/'output_files/test_board.sta.summary'}
if any(not p.is_file() for p in paths.values()):
    raise SystemExit('Rapid parent lacks its successful build/input/image/STA evidence')
r=json.loads(paths['parent_build_result_sha256'].read_text())
m=json.loads(paths['parent_inputs_sha256'].read_text())
c=parent/'v2-compile-inputs.json'
if not c.is_file(): raise SystemExit('Rapid parent lacks its compile-input snapshot')
inputs=json.loads(c.read_text())
hashes={k:sha256(p) for k,p in paths.items()}
if (r.get('format') not in ('jttms10-incremental-build-result-v1',RAPID_RESULT_FORMAT) or
    r.get('flow_exit_code')!=0 or r.get('inputs_unchanged') is not True or
    r.get('input_manifest_sha256')!=hashes['parent_inputs_sha256'] or
    r.get('rbf_sha256')!=hashes['parent_image_sha256'] or
    r.get('compile_inputs_sha256')!=sha256(c) or
    inputs.get('map_manifest_sha256')!=hashes['parent_inputs_sha256'] or
    not inputs.get('files') or not m.get('files')):
    raise SystemExit('Rapid parent result does not certify its frozen inputs/image')
for name,digest in inputs['files'].items():
    p=Path(name)
    if not p.is_file() or sha256(p)!=digest:
        raise SystemExit(f'Rapid parent compile input is missing or changed: {name}')
if r['format']==RAPID_RESULT_FORMAT:
    validate_rapid_result(parent,r)
elif r.get('full_flow_only') is not True:
    raise SystemExit('Rapid parent must be a certified full or Rapid build')
validate_positive_sta(paths['parent_sta_summary_sha256'])
if not (parent/'db').is_dir() or not any((parent/'db').iterdir()):
    raise SystemExit('Rapid parent lacks its retained Quartus database')
print(json.dumps(dict(format='jttms10-rapid-parent-v1',parent_build_dir=str(parent),**hashes)))
PY
)
}

prepare_build() {
    cp -a --reflink=auto "$base_dir" "$build_dir"
    python3 - "$base_dir" "$build_dir" "$repo_root" "$source_dir" "$stage" <<'PY'
from pathlib import Path
import sys
base, build, repo, source = map(Path, sys.argv[1:5])
stage = sys.argv[5]
sys.path.insert(0, str(source))
import partition_build
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
              'v2-compile-inputs.json','build-input-manifest.post.json',
              'v2-rapid-parent.json','v2-rapid-time.json','v2-rapid-command.json',
              'v2-partition-stage-precompile.json','v2-partition-stage-result.json',
              'v2-partition-query.tcl','v2-partition-source-delta.json',
              'v2-partition-parent.json','v2-generated-payloads.json'):
    (build/stale).unlink(missing_ok=True)
partition_build.clear_inherited_seed_package_audit(build)

ip = build / 'ip/jttms10_fpga_runner'
source_hdl = repo / 'modules/jttms10/hdl'
source_verilog = {p.name for p in source_hdl.glob('*.v')}
package_verilog = {p.name for p in ip.glob('*.v') if p.name not in {'jttms10_fpga_runner.v','jttms10_fpga_stimulus.v'}}
if stage == 'partition-seed':
    try:
        audit = partition_build.reconstruct_seed_cpu_package(base, build, repo)
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from error
    (build/'v2-partition-seed-package-reconstruction.json').write_text(
        __import__('json').dumps(audit,indent=2,sort_keys=True)+'\n')
    package_verilog = {p.name for p in ip.glob('*.v')
                       if p.name not in {'jttms10_fpga_runner.v','jttms10_fpga_stimulus.v'}}
elif source_verilog != package_verilog:
    raise SystemExit(f'CPU HDL file set changed: source={sorted(source_verilog)}, package={sorted(package_verilog)}')
if source_verilog != package_verilog:
    raise SystemExit(f'CPU HDL file set changed after seed package reconstruction: source={sorted(source_verilog)}, package={sorted(package_verilog)}')
for path in source_hdl.glob('*.v'):
    (ip / path.name).write_bytes(path.read_bytes())
for name in ('jttms10_fpga_runner.v', 'jttms10_fpga_stimulus.v'):
    (ip / name).write_bytes((repo / 'modules/jttms10/ver/fpga' / name).read_bytes())
    line = f'set_global_assignment -library "QSYS_test_board" -name VERILOG_FILE {(ip/name).resolve()}'
    if line not in qsf.read_text().splitlines():
        with qsf.open('a') as output:
            output.write(line+'\n')
PY
}

regenerate_payload() {
    local generated_tmp
    generated_tmp=$(mktemp -d "${TMPDIR:-/tmp}/jttms10-runner-generated.XXXXXX")
    trap 'rm -rf -- "$generated_tmp"' RETURN
    bash "$repo_root/modules/jttms10/ver/build.sh" "$generated_tmp"
    python3 - "$build_dir" "$generated_tmp" "$stage" "$repo_root" "$source_dir" <<'PY'
from pathlib import Path
import hashlib, json, shutil, sys
build, generated = map(Path, sys.argv[1:3])
stage = sys.argv[3]
repo, helper = map(Path, sys.argv[4:6])
sys.path.insert(0, str(helper))
import partition_build
package = build / 'ip/jttms10_fpga_runner'
generated_root = build/'jttms10-generated'
roots = (package, build)
extensions = ('.uc', '.hex', '.vh')
files = {p.name:p for p in generated.iterdir() if p.is_file() and p.suffix in extensions}
if set(files) != partition_build.GENERATED_CPU_PAYLOADS:
    raise SystemExit('ucode build produced an unexpected CPU payload set: '
                     f'expected={sorted(partition_build.GENERATED_CPU_PAYLOADS)} actual={sorted(files)}')
if generated_root.exists():
    shutil.rmtree(generated_root)
shutil.copytree(generated, generated_root)
for root in roots:
    root.mkdir(parents=True, exist_ok=True)
    for old in root.iterdir():
        generated_name = old.name.startswith('tms10')
        if old.is_file() and old.suffix in extensions and generated_name and old.name not in files:
            raise SystemExit(f'unclassified stale generated CPU payload remains: {root}/{old.name}')
    for name, source in files.items():
        (root/name).write_bytes(source.read_bytes())
for name, source in files.items():
    for root in (generated_root, *roots):
        if (root/name).read_bytes() != source.read_bytes():
            raise SystemExit(f'generated payload copy mismatch: {name} in {root}')
if stage in ('partition-seed','partition-update-microcode'):
    digest=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    payloads={name:digest(path) for name,path in sorted(files.items())}
    copies={}
    for name in sorted(files):
        for root in (build,generated_root,package):
            path=root/name
            copies[path.relative_to(build).as_posix()]=digest(path)
    manifest={'format':partition_build.GENERATED_PAYLOAD_FORMAT,
              'generator_sha256':digest(repo/'modules/jttms10/ver/build.sh'),
              'payloads':payloads,'copies':copies}
    (build/'v2-generated-payloads.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
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
sys.path.insert(0, str(source))
import partition_build
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024), b''): h.update(block)
    return h.hexdigest()
source_roots=(repo/'modules/jttms10/ucode',repo/'modules/jttms10/ver/decoder',
              repo/'modules/jttms10/ver/gfx',repo/'modules/jttms10/hdl',
              repo/'modules/jtframe/src/jtframe/ucode')
source_files={repo/'modules/jttms10/ver/build.sh', repo/'modules/jtframe/bin/jtframe',
              source/'build-runner-incremental.sh',source/'write_programming_receipt.py',
              source/'partition_build.py'}
source_files.update((repo/'modules/jttms10/ver/fpga').glob('*.v'))
for root in source_roots:
    source_files.update(p for p in root.rglob('*') if p.is_file())
source_hashes={str(p):digest(p) for p in sorted(source_files)
               if p.is_file() and p.suffix != '.pyc' and '__pycache__' not in p.parts}
inputs=[build/'test_board.qsf',build/'test_board.qpf',build/'test_board.bdf',
        build/'QSYS_test_board.qsys',build/'QSYS_test_board.tcl',build/'QSYS_test_board.sopcinfo',
        build/'runner_clock.sdc',build/'QSYS_test_board/synthesis/QSYS_test_board.qip']
inputs += [p for p in build.iterdir() if p.is_file() and p.suffix.lower() in ('.v','.vh','.hex','.uc')]
inputs += [p for root in (build/'ip/jttms10_fpga_runner',)
           for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.v','.vh','.hex','.uc')]
generated_root=build/'jttms10-generated'
generated_diagnostics={}
for path in generated_root.rglob('*'):
    if not path.is_file(): continue
    relative=(Path('jttms10-generated')/path.relative_to(generated_root)).as_posix()
    if partition_build.is_non_compile_generated_output(relative):
        generated_diagnostics[relative]=digest(path)
    elif relative in partition_build.CPU_GENERATED_COMPILE_INPUTS:
        inputs.append(path)
    else:
        raise SystemExit(f'unclassified generated CPU output: {relative}')
try:
    generated_inventory=partition_build.cpu_generated_output_inventory(generated_root)
except ValueError as error:
    raise SystemExit(str(error)) from error
if generated_inventory['diagnostics'] != generated_diagnostics:
    raise SystemExit('generated diagnostic inventory changed while freezing inputs')
inputs += [p for p in (build/'QSYS_test_board/synthesis').rglob('*') if p.is_file()]
inputs += [build/name for name in ('v2-partition-parent.json',
    'v2-partition-stage-precompile.json','v2-partition-query.tcl')
    if (build/name).is_file()]
if (build/'v2-rapid-parent.json').is_file(): inputs.append(build/'v2-rapid-parent.json')
inputs=sorted(set(p for p in inputs if p.is_file()))
quartus='/opt/quartus_free/quartus_sh'
version=subprocess.run([quartus,'--version'],capture_output=True,text=True)
manifest={'format':'jttms10-incremental-build-inputs-v2','base_build':str(base),
          'source_root':str(repo.resolve()),
          'source_hashes':source_hashes,'files':{str(p):digest(p) for p in inputs},
          'non_compile_generated_outputs':generated_diagnostics,
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
for relative,expected in manifest.get('non_compile_generated_outputs',{}).items():
    p=build/relative
    if not p.is_file() or digest(p)!=expected:
        raise SystemExit(f'generated diagnostic output changed since map stage: {relative}')
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
for relative,expected in m.get('non_compile_generated_outputs',{}).items():
    path=b/relative
    if not path.is_file() or digest(path)!=expected:
        raise SystemExit(f'generated diagnostic output changed after map: {relative}')
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

run_rapid() {
    python3 - "$build_dir" <<'PY'
from pathlib import Path
import json,subprocess,sys,time
b=Path(sys.argv[1])
command=['/opt/quartus_free/quartus_sh','--flow','recompile','test_board']
record=dict(command=command,cwd=str(b),start_monotonic_ns=time.monotonic_ns())
(b/'v2-rapid-command.json').write_text(json.dumps(record,indent=2)+'\n')
with (b/'logs/v2-compile.log').open('w') as log:
    result=subprocess.run(command,cwd=b,stdout=log,stderr=subprocess.STDOUT)
record.update(end_monotonic_ns=time.monotonic_ns(),exit_code=result.returncode)
record['seconds']=(record['end_monotonic_ns']-record['start_monotonic_ns'])/1e9
(b/'v2-rapid-time.json').write_text(json.dumps(record,indent=2)+'\n')
(b/'logs/v2-compile.time').write_text(f"seconds={record['seconds']:.9f}\nexit_code={result.returncode}\n")
raise SystemExit(result.returncode)
PY
}

write_rapid_result() {
    python3 - "$build_dir" "$source_dir" <<'PY'
from pathlib import Path
import json,math,re,sys
b,source=map(Path,sys.argv[1:])
sys.path.insert(0,str(source))
from write_programming_receipt import RAPID_RESULT_FORMAT,sha256,validate_rapid_result
inputs=json.loads((b/'v2-compile-inputs.json').read_text())
for name,expected in inputs['files'].items():
    p=Path(name)
    if not p.is_file() or sha256(p)!=expected:
        raise SystemExit(f'input changed during Rapid Recompile: {name}')
timing=json.loads((b/'v2-rapid-time.json').read_text())
command=['/opt/quartus_free/quartus_sh','--flow','recompile','test_board']
command_record=json.loads((b/'v2-rapid-command.json').read_text())
if (timing.get('exit_code')!=0 or timing.get('command')!=command or
    timing.get('cwd')!=str(b) or timing.get('seconds',0)<=0 or
    timing.get('end_monotonic_ns',0)<=timing.get('start_monotonic_ns',0) or
    command_record!={k:timing[k] for k in ('command','cwd','start_monotonic_ns')} or
    not math.isclose(timing['seconds'],
        (timing['end_monotonic_ns']-timing['start_monotonic_ns'])/1e9,rel_tol=0,abs_tol=1e-9)):
    raise SystemExit('Rapid Recompile did not finish successfully with measured wall time')
rbf=b/'output_files/test_board.rbf'
if not rbf.is_file() or rbf.stat().st_mtime_ns <= (b/'v2-compile-inputs.json').stat().st_mtime_ns:
    raise SystemExit('Rapid Recompile image is missing or stale')
log=b/'logs/v2-compile.log'
text=log.read_text(errors='replace')
marker='Quartus Prime Rapid Recompile was successful'
reports={s:b/f'output_files/test_board.{s}.rpt' for s in ('map','fit','asm','sta')}
if any(not p.is_file() for p in reports.values()):
    raise SystemExit('Rapid Recompile lacks map/fit/assembly/STA reports')
parent=json.loads((b/'v2-rapid-parent.json').read_text())
parent.pop('format')
result=dict(format=RAPID_RESULT_FORMAT,flow_kind='recompile',command=command,
    working_directory=str(b),full_flow_only=False,flow_exit_code=0,
    flow_seconds=timing['seconds'],flow_wrapper_wall_seconds=timing['seconds'],
    rapid_time_sha256=sha256(b/'v2-rapid-time.json'),
    rapid_command_sha256=sha256(b/'v2-rapid-command.json'),
    flow_log_sha256=sha256(log),terminal_marker=marker,inputs_unchanged=True,
    input_manifest_sha256=sha256(b/'v2-build-inputs.json'),
    compile_inputs_sha256=sha256(b/'v2-compile-inputs.json'),
    pre_map_metadata_deltas=inputs['pre_map_metadata_deltas'],
    rbf_sha256=sha256(rbf),stage_reports={s:sha256(p) for s,p in reports.items()},
    sta_summary_sha256=sha256(b/'output_files/test_board.sta.summary'),**parent)
elapsed=re.findall(r'Elapsed time: (\d+):(\d+):(\d+)',text)
if elapsed:
    h,m,s=map(int,elapsed[-1]);result['flow_log_elapsed_seconds']=h*3600+m*60+s
validate_rapid_result(b,result)
(b/'v2-build-result.json').write_text(json.dumps(result,indent=2)+'\n')
PY
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

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
