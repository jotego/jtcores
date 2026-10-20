#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

import argparse
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('scenes', nargs='*')
    args = parser.parse_args()
    core = Path(__file__).resolve().parents[2]
    repo = core.parents[1]
    folder = core / 'ver/roundup5'
    suite = json.loads((folder / 'scene-capture.json').read_text())
    selected = args.scenes or [s['name'] for s in suite['scenes']]
    assert selected and all(s.isdigit() and s in {v['name'] for v in suite['scenes']} for s in selected)
    image = os.environ.get('JTFRAME_SIM_IMAGE', 'jotego/simulator:arm64')
    image_id = subprocess.check_output(['docker', 'image', 'inspect', '--format', '{{.Id}}', image], text=True).strip()
    docker = ['docker', 'run', '--rm', '--pull=never', '--entrypoint', '/bin/bash',
              '-v', str(repo) + ':/jtcores', '-v', str(repo / 'modules') + ':/jtcores/modules:ro',
              '-w', '/jtcores/cores/roundu/ver/roundup5', image]
    version = subprocess.check_output(docker + ['-lc', 'verilator --version'], text=True).strip()
    sources = [core / 'ver/hdl/video_scene_tb.v',
               *(core / 'hdl' / n for n in ['jtroundu_video.v', 'jtroundu_text.v', 'jtroundu_obj.v', 'jtroundu_bg.v', 'jtroundu_road.v']),
               *(repo / 'modules/jtframe/hdl/video/tilemap').glob('*.v'),
               *(repo / 'modules/jtframe/hdl/ram' / n for n in ['jtframe_obj_buffer.v', 'jtframe_dual_ram.v', 'jtframe_dual_ram16.v'])]
    sources += list(core.glob('hdl/*_mmr.v'))
    mdir = 'obj_video_scene'
    command = ['verilator', '--binary', '--timing', '--assert', '-j', '4', '-Wno-fatal',
               '--top-module', 'video_scene_tb', '--Mdir', mdir, '-o', 'sim', '-DSIMULATION',
               '-DROUNDU_SCENE_PATH="scene-work/"',
               *(str(Path('/jtcores') / p.relative_to(repo)) for p in sources)]
    runtime = docker + ['-lc', 'exec "$@"', 'roundu-replay']
    with (folder / 'scene-build.log').open('w') as log:
        subprocess.run(runtime + command, stdout=log, stderr=subprocess.STDOUT, check=True)
    (folder / 'scene-simulator.json').write_text(json.dumps(dict(engine='Verilator', version=version,
        image=image, image_id=image_id, command=command, working_directory=str(folder),
        cpu_mode='disabled; video testbench', raster_master_clocks_per_pixel=32), indent=2) + '\n')
    for name in selected:
        oracle = ['python3', str(core / 'ver/game/video-oracle.py'), '--scene', name]
        subprocess.run(oracle + ['--record-sources'], check=True)
        with (folder / (name + '-replay.log')).open('w') as log:
            subprocess.run(runtime + ['./' + mdir + '/sim'], stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run(oracle + ['--check'], check=True)


if __name__ == '__main__':
    main()
