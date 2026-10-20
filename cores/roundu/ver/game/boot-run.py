#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

import argparse
import array
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import wave


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--frames', type=int, default=1560)
    parser.add_argument('--label', default='boot-play')
    parser.add_argument('--inputs')
    args = parser.parse_args()
    assert re.fullmatch(r'[a-z0-9-]+', args.label)
    core = Path(__file__).resolve().parents[2]
    repo = core.parents[1]
    folder = core / 'ver/roundup5'
    image = os.environ.get('JTFRAME_SIM_IMAGE', 'jotego/simulator:arm64')
    paths = [*core.glob('hdl/*.v'), *core.glob('cfg/*'),
             * (repo / 'modules/jtframe/hdl/cpu/nuv30').rglob('*.sv'),
             * (repo / 'modules/jtframe/hdl/cpu/nuv30').rglob('*.svh'),
             repo / 'modules/jtframe/hdl/cpu/jtframe_v30.sv',
             Path(__file__), core / 'ver/game/sim.sh']
    if args.inputs:
        paths.append((folder / args.inputs).resolve())
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    command = ['bash', str(core / 'ver/game/sim.sh'), '--preload', '-d', 'ROUNDU_TRACE',
               '-video', str(args.frames), '-time', str(max(10000, args.frames * 20))]
    if args.inputs:
        command += [args.inputs]
    report = dict(status='running', command=command,
                  image=image, image_id=subprocess.check_output(['docker', 'image', 'inspect',
                  '--format', '{{.Id}}', image], text=True).strip(),
                  requested_frames=args.frames, inputs=args.inputs,
                  scanline_timing_verified=False, full_board_restore=False,
                  source_sha256={str(p.relative_to(repo)): digest(p) for p in paths if p.is_file()},
                  rom_sha256=digest(repo / 'rom/roundup5.rom'))
    manifest = folder / (args.label + '.json')
    manifest.write_text(json.dumps(report, indent=2) + '\n')
    with (folder / (args.label + '.log')).open('w') as log:
        result = subprocess.run(command, cwd=folder, stdout=log, stderr=subprocess.STDOUT)
    report['exit_code'] = result.returncode
    report['sources_unchanged'] = all(digest(repo / p) == h for p, h in report['source_sha256'].items())
    report['status'] = 'completed_pending_visual_review' if result.returncode == 0 else 'failed'
    frames = sorted((folder / 'frames').glob('frame_*.png'))
    if frames:
        destination = folder / 'sim_results' / (args.label + '-last.png')
        shutil.copy2(frames[-1], destination)
        report['last_emitted_frame'] = frames[-1].name
        report['last_image'] = str(destination.relative_to(folder))
    audio = folder / 'test.wav'
    if result.returncode == 0 and audio.is_file():
        shutil.copy2(audio, folder / (args.label + '.wav'))
        with wave.open(str(audio)) as wav:
            samples = array.array('h', wav.readframes(wav.getnframes()))
            report['audio'] = dict(rate=wav.getframerate(), channels=wav.getnchannels(),
                                   frames=wav.getnframes(), nonzero=sum(s != 0 for s in samples),
                                   peak=max(map(abs, samples), default=0))
    manifest.write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
