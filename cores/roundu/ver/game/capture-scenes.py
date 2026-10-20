#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
from PIL import Image, ImageDraw
from scene_contract import CORE, REPO, SET, prepare, registers, sha, split


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--frames', type=int, nargs='+', default=list(range(300, 6001, 300)))
    parser.add_argument('--replace', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    env = dict(os.environ, JTROOT=str(REPO), JTFRAME=str(REPO / 'modules/jtframe'),
               CORES=str(REPO / 'cores'), MODULES=str(REPO / 'modules'), JTBIN=str(REPO / 'release'))
    with (SET / 'mmr-generation.log').open('w') as log:
        subprocess.run([str(REPO / 'modules/jtframe/bin/jtframemac'), 'mmr', 'roundu'],
                       env=env, cwd=SET, stdout=log, stderr=subprocess.STDOUT, check=True)
    profile = prepare()
    if args.prepare_only:
        print('PROFILE_READY: 13 video blocks, 4 MMR blocks, 612 register bytes')
        return
    binary = Path(os.environ.get('MAME_BINARY', '/Users/andreabogazzi/Emus/mame0276-arm64/mame'))
    rompath = Path(os.environ.get('MAME_ROMPATH', str(Path.home() / '.mame/roms-local')))
    version = subprocess.check_output([str(binary), '-help'], text=True).splitlines()[0]
    assert version.startswith('MAME v0.282 '), 'Use the approved MAME 0.282 executable'
    archive = next(p for ext in ['7z', 'zip'] if (p := rompath / ('roundup5.' + ext)).is_file())
    frames = sorted(set(args.frames))
    assert frames and all(f > 0 for f in frames)
    scenes = SET / 'scenes'
    scenes.mkdir(exist_ok=True)
    if any(scenes.iterdir()):
        assert args.replace, 'Existing captures require --replace'
        shutil.rmtree(scenes)
        scenes.mkdir()
    inputs = [dict(frame=700, field='Start 1', value=1), dict(frame=710, field='Start 1', value=0),
              dict(frame=800, field='Accelerator', value=1)]
    suite = dict(status='capturing', core='roundu', game='roundup5', profile=profile,
                 executable=str(binary), version=version, executable_sha256=sha(binary),
                 rom_archive=str(archive), rom_archive_sha256=sha(archive),
                 capture_script_sha256=sha(CORE / 'ver/game/capture_video.lua'),
                 launcher_sha256=sha(Path(__file__)), frames=frames, inputs=inputs,
                 reference='Native 320x240, no bilinear scaling, video state held from F to F+1',
                 scenes=[])
    manifest = SET / 'scene-capture.json'
    manifest.write_text(json.dumps(suite, indent=2) + '\n')
    settings = SET / 'capture-settings'
    with (SET / 'scene-capture.log').open('w') as log:
        for frame in frames:
            target = scenes / str(frame)
            target.mkdir()
            if settings.exists():
                shutil.rmtree(settings)
            settings.mkdir()
            capture_env = dict(env, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy',
                               ROUNDU_CAPTURE=str(target), ROUNDU_CAPTURE_FRAME=str(frame),
                               ROUNDU_TEST='0', ROUNDU_PLAY='1', ROUNDU_DRIVE='1')
            command = [str(binary), 'roundup5', '-rompath', str(rompath), '-noreadconfig',
                       '-inipath', str(settings), '-homepath', str(settings), '-cfg_directory', str(settings),
                       '-nvram_directory', str(settings), '-snapshot_directory', str(settings),
                       '-video', 'soft', '-window', '-sound', 'none', '-nothrottle', '-skip_gameinfo',
                       '-snapview', 'native', '-nosnapbilinear', '-autoboot_script',
                       str(CORE / 'ver/game/capture_video.lua'), '-autoboot_delay', '0',
                       '-seconds_to_run', str(frame // 57 + 5)]
            result = subprocess.run(command, cwd=SET, env=capture_env, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=180)
            log.write(f'FRAME {frame}\n' + result.stdout + '\n')
            log.flush()
            assert result.returncode == 0 and f'VIDEO_REFERENCE_OK frame={frame + 1} video_state_held=1' in result.stdout
            raw = (target / 'dump.bin').read_bytes()
            mmr, fields = registers(split(raw))
            (target / 'mmr.bin').write_bytes(mmr)
            assert Image.open(target / 'screen.png').size == (320, 240)
            assert set(p.name for p in target.iterdir()) == {'dump.bin', 'screen.png', 'mmr.bin'}
            suite['scenes'].append(dict(name=str(frame), frame=frame, reference_frame=frame + 1,
                files={p.name: sha(p) for p in target.iterdir()}, registers=fields,
                applied_inputs=[i for i in inputs if i['frame'] <= frame], command=command))
            manifest.write_text(json.dumps(suite, indent=2) + '\n')
            print('CAPTURED ' + str(frame), flush=True)
    overview = Image.new('RGB', (320 * 5, 260 * ((len(frames) + 4) // 5)), '#202020')
    draw = ImageDraw.Draw(overview)
    for i, frame in enumerate(frames):
        x, y = i % 5 * 320, i // 5 * 260
        overview.paste(Image.open(scenes / str(frame) / 'screen.png'), (x, y + 20))
        draw.text((x + 4, y + 3), str(frame), fill='white')
    overview.save(SET / 'scene-overview.png')
    suite['status'] = 'complete'
    suite['actual_scene_count'] = len(suite['scenes'])
    manifest.write_text(json.dumps(suite, indent=2) + '\n')
    shutil.rmtree(settings)
    print('SUITE_COMPLETE: ' + str(len(frames)) + ' scenes')


if __name__ == '__main__':
    main()
