#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prove FILL frame, checkpoint timing, and RETI checks reject CPU mutations."""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
TMS=HERE.parents[1]
MODULE=TMS
DEFAULT_HDL=TMS/'hdl'
REFERENCE=HERE/'check_external_reference.py'
MUTATIONS=(
    ('missing_fill_pbx_saved_st','jttms10.v',
     "md<=st | (pbx_push ? 32'h0200_0000 : 32'd0);",
     "md<=st;",('final fill memory, PBX stack frame','write payload differs')),
    ('overlong_reti_decode','jttms10.v',
     "stack_irq ? 16'd2 : copy_long_finish", "stack_irq ? 16'd8 : copy_long_finish",
     ('cold aligned RETI: expected 160 INCLK',)),
)


def make_overlong_checkpoint_source(root):
    """Delay the registered graphics checkpoint, only while FILL IRQ is pending."""
    hdl=root/'overlong_fill_checkpoint-hdl'
    shutil.copytree(DEFAULT_HDL,hdl)
    source=hdl/'jttms10_gfx.v'
    text=source.read_text()
    anchor='    reg condition;\n'
    counter=("    reg condition;\n"
             "    reg [7:0] fill_irq_delay;\n"
             "    always @(posedge clk) begin\n"
             "        if(rst || !irq_pending) fill_irq_delay<=0;\n"
             # 200 INCLK ticks are 25 machine states; this crosses §13.3.4's 20.
             "        else if(fill_irq_delay<8'd200) fill_irq_delay<=fill_irq_delay+1'b1;\n"
             "    end\n")
    if text.count(anchor)!=1:
        raise RuntimeError('FILL timing mutation could not find graphics condition register')
    text=text.replace(anchor,counter)
    old='checkpoint<=gflow==CHECK_GFLOW;'
    new=('checkpoint<=gflow==CHECK_GFLOW &&\n'
         "                (!word_fill || !irq_pending || fill_irq_delay>=8'd200);")
    if text.count(old)!=1:
        raise RuntimeError('FILL timing mutation could not find registered CHECK_GFLOW output')
    source.write_text(text.replace(old,new))
    return hdl


def run_overlong_checkpoint_mutation(root,reference_dir):
    hdl=make_overlong_checkpoint_source(root)
    output=root/'overlong_fill_checkpoint'
    output.mkdir(parents=True,exist_ok=False)
    reference=Path(reference_dir)
    if not (reference/'manifest.json').is_file() or not (reference/'reference.json').is_file():
        raise RuntimeError('known-good four-case CPU77 reference is unavailable')
    if str(HERE) not in sys.path:
        sys.path.insert(0,str(HERE))
    import check_results as checker
    baseline_manifest=json.loads((reference/'manifest.json').read_text())
    selected=[]
    for batch in baseline_manifest['batches']:
        for entry,descriptor in zip(batch['cases'],batch['descriptors']):
            if entry['external_contract']['interrupt']=='nmi':
                selected_entry=dict(entry)
                selected_entry['id']=descriptor[0]
                selected.append(selected_entry)
    if len(selected)!=2:
        raise RuntimeError('timing mutation requires both NMI FILL engine cases')
    manifest=dict(format=baseline_manifest['format'],protocol_version=5,
                  oracle_sha256=baseline_manifest['oracle_sha256'],
                  batches=checker.make_batches(selected,protocol_version=5))
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    baseline_reference=json.loads((reference/'reference.json').read_text())
    reference_cases={entry['name']:entry for entry in baseline_reference['cases']}
    (output/'reference.json').write_text(json.dumps(dict(
        cases=[reference_cases[entry['name']] for entry in selected],
        source_sha256=baseline_reference['source_sha256'],
        generated_sha256=baseline_reference['generated_sha256'],
        backend=baseline_reference['backend']),indent=2)+'\n')
    runner=HERE/'check_runner.py'
    avalon=output/'avalon'
    avalon_command=[sys.executable,str(runner),'--manifest',str(output/'manifest.json'),
                    '--reference',str(output/'reference.json'),'--cpu-rtl-dir',str(hdl),
                    '--output',str(avalon)]
    avalon_result=subprocess.run(avalon_command,text=True,capture_output=True)
    (root/'overlong_fill_checkpoint-mutant-command.log').write_text(
        'argv: '+repr(avalon_command)+'\nexit: '+str(avalon_result.returncode)+'\n'+
        avalon_result.stdout+avalon_result.stderr)
    report_path=avalon/'report.json'
    if not report_path.is_file():
        raise RuntimeError('overlong FILL Avalon run emitted no report')
    report=json.loads(report_path.read_text())
    av_errors=[error for batch in report['batches'] for case in batch['cases'] for error in case['errors']]
    diagnostic='FILL request to selected word/row checkpoint: expected 0..161 INCLK, observed'
    if not avalon_result.returncode or not any(diagnostic in error for error in av_errors):
        raise RuntimeError(f'Avalon FILL timing bound missed delayed gate: {av_errors}')
    control=output/'nop-control'
    control_command=[sys.executable,str(runner),'--case','nop_hit','--cpu-rtl-dir',str(hdl),
                     '--output',str(control)]
    control_result=subprocess.run(control_command,text=True,capture_output=True)
    (root/'overlong_fill_checkpoint-nop-command.log').write_text(
        'argv: '+repr(control_command)+'\nexit: '+str(control_result.returncode)+'\n'+
        control_result.stdout+control_result.stderr)
    control_report=control/'report.json'
    if control_result.returncode or not control_report.is_file():
        raise RuntimeError('NOP control failed for FILL microcode timing mutation')
    control_data=json.loads(control_report.read_text())
    if not control_data.get('batches') or any(batch.get('failed',0) for batch in control_data['batches']):
        raise RuntimeError(f'NOP control failed for FILL microcode timing mutation: {control_data}')
    print('overlong_fill_checkpoint: PASS; literal FILL timing bound rejected delayed gate; NOP control passed')


def replace_once(path,old,new):
    source=path.read_text()
    if source.count(old)!=1:
        raise RuntimeError(f'mutation site changed: {path.name}: {old!r}')
    path.write_text(source.replace(old,new))


def run_mutation(mutation,root):
    name,filename,old,new,needles=mutation
    hdl=root/(name+'-hdl')
    shutil.copytree(DEFAULT_HDL,hdl)
    replace_once(hdl/filename,old,new)
    output=root/name
    command=[sys.executable,str(REFERENCE),'--graphics-fill-irq','--cpu-rtl-dir',str(hdl),
             '--output',str(output)]
    result=subprocess.run(command,text=True,capture_output=True)
    report_path=output/'avalon'/'report.json'
    if not report_path.is_file():
        raise RuntimeError(f'{name}: runner failed before contract report\n{result.stdout}{result.stderr}')
    reference=json.loads((output/'reference.json').read_text())
    report=json.loads(report_path.read_text())
    if any(case['errors'] for case in reference['cases']):
        raise RuntimeError(f'{name}: unmutated original-system positive reference failed')
    errors=[message for batch in report['batches'] for case in batch['cases'] for message in case['errors']]
    missing=[needle for needle in needles if not any(needle in error for error in errors)]
    if result.returncode==0 or missing:
        raise RuntimeError(f'{name}: independent FILL contract missed mutation; missing={missing}; errors={errors}')
    control_output=root/(name+'-nop-control')
    control=[sys.executable,str(HERE/'check_runner.py'),'--case','nop_hit',
             '--cpu-rtl-dir',str(hdl),'--output',str(control_output)]
    control_result=subprocess.run(control,text=True,capture_output=True)
    control_report=control_output/'report.json'
    if control_result.returncode or not control_report.is_file():
        raise RuntimeError(f'{name}: NOP control failed\n{control_result.stdout}{control_result.stderr}')
    data=json.loads(control_report.read_text())
    if not data.get('batches') or any(batch.get('failed',0) for batch in data['batches']):
        raise RuntimeError(f'{name}: NOP control failed: {data}')
    print(f'{name}: PASS; literal FILL contract rejected mutation ({len(errors)} diagnostics), NOP control passed')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,help='new directory retaining temporary CPU variants and reports')
    args=parser.parse_args()
    if args.output:
        root=args.output.resolve();root.mkdir(parents=True,exist_ok=False)
        for mutation in MUTATIONS: run_mutation(mutation,root)
        run_overlong_checkpoint_mutation(root,root/MUTATIONS[0][0])
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-fill-irq-mutations-') as temp:
            root=Path(temp)
            for mutation in MUTATIONS: run_mutation(mutation,root)
            run_overlong_checkpoint_mutation(root,root/MUTATIONS[0][0])


if __name__=='__main__': main()
