#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

import argparse
import csv
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('scenes', nargs='*')
    args = parser.parse_args()
    core = Path(__file__).resolve().parents[2]
    repo = core.parents[1]
    folder = core / 'ver/roundup5'
    output = folder / 'sim_results/diff'
    output.mkdir(exist_ok=True)
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    suite = json.loads((folder / 'scene-capture.json').read_text())
    replay = json.loads((folder / 'scene-replay.json').read_text())
    assert all(digest(repo / p) == h for p, h in replay['source_sha256'].items())
    rows = []
    for name in args.scenes or [s['name'] for s in suite['scenes']]:
        scene = folder / 'scenes' / name
        report = replay['scenes'][name]
        capture = next(s for s in suite['scenes'] if s['name'] == name)
        assert hashlib.sha256(json.dumps(capture, sort_keys=True).encode()).hexdigest() == report['capture_sha256']
        assert digest(folder / report['image']) == report['image_sha256']
        assert all(digest(scene / p) == h for p, h in capture['files'].items())
        assert report['mmr_bytes_verified'] == 612 and report['mmr_fields_verified'] == 16
        reference = Image.open(scene / 'screen.png').convert('RGB')
        actual = Image.open(folder / report['image']).convert('RGB')
        assert reference.size == actual.size == (320, 240)
        diff = ImageChops.difference(reference, actual)
        raw = diff.tobytes()
        values = list(zip(raw[0::3], raw[1::3], raw[2::3]))
        count = sum(any(p) for p in values)
        assert count == report['mame_context_differing_pixels']
        heat = Image.new('RGB', reference.size)
        heat.putdata([(255, 0, 0) if any(p) else (0, 0, 0) for p in values])
        stack = Image.new('RGB', (960, 240))
        for x, image in [(0, reference), (320, actual), (640, heat)]:
            stack.paste(image, (x, 0))
        image_path = output / (name + '.png')
        stack.save(image_path)
        rows.append(dict(scene=name, compared_pixels=76800, differing_pixels=count,
                         differing_percent=count / 768, mean_absolute_channel_difference=sum(map(sum, values)) / 230400,
                         bounding_box=diff.getbbox(), transform='native 320x240; no crop, rotation, shift or mask',
                         reference_sha256=digest(scene / 'screen.png'), replay_sha256=report['image_sha256'],
                         comparison=str(image_path.relative_to(folder)),
                         replay='scene-replay.json'))
    (folder / 'scene-diff.json').write_text(json.dumps(dict(scope='functional video replay; CPUs disabled in testbench',
        scanline_timing_verified=False, video_register_restore_verified=True, scenes=rows), indent=2) + '\n')
    with (folder / 'scene-diff.csv').open('w') as handle:
        writer = csv.DictWriter(handle, fieldnames=['scene', 'compared_pixels', 'differing_pixels', 'differing_percent', 'mean_absolute_channel_difference'], extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    for row in rows:
        print(f"{row['scene']}: {row['differing_pixels']}/76800 native MAME pixels differ")


if __name__ == '__main__':
    main()
