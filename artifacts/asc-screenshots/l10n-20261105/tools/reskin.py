#!/usr/bin/env python3
"""Replace captures and CoreText headers in finished screenshot frames."""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path
from typing import Optional

from PIL import Image, ImageDraw

from common import config, destinations, erase_header, header_job, headline, paste_screen, raw_path, read_json, source


def extra_job(extra: dict, text: str, locale: str, out: Optional[Path]) -> dict:
    return {
        "text": text,
        "locale": locale,
        "font": extra["font"],
        "color": extra["color"],
        "box": extra["box"][2:],
        "maxSize": extra.get("max_size", 48),
        "minSize": extra.get("min_size", 1),
        "align": extra.get("align", "center"),
        "out": str(out) if out else None,
    }


def paint_extra_background(canvas: Image.Image, extra: dict, plate: Image.Image = None) -> None:
    box = extra["box"]
    if "fill_color" not in extra:
        erase_header(canvas, box, plate)
        return
    x, y, width, height = box
    radius = extra.get("radius", height / 2)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (x, y, x + width - 1, y + height - 1),
        radius=radius,
        fill=tuple(extra["fill_color"]),
    )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--raw-root', type=Path, required=True)
    p.add_argument('--headers', type=Path, required=True)
    p.add_argument('--locale', required=True)
    p.add_argument('--out', type=Path, required=True, help='output root; writes ROOT/LOCALE/SET/file.png')
    p.add_argument('--set', dest='set_key')
    args = p.parse_args()
    data, headers = config(args.config), read_json(args.headers)[args.locale]
    sets = data['sets'] if args.set_key is None else {args.set_key: data['sets'][args.set_key]}
    plans = []
    extra_jobs = []
    extras_by_frame = {}
    for key, group in sets.items():
        frames = group['frames']
        jobs = [header_job(f, headers[f['file']], args.locale) for f in frames]
        results = headline(jobs)
        size = min(r['size'] for r in results)
        cause = frames[min(range(len(results)), key=lambda i: results[i]['size'])]
        for f, result in zip(frames, results):
            if not result['fits'] or size < f['min_size']:
                raise ValueError(f"{key}/{cause['file']}: size {size:g} below required minimum; text={headers[cause['file']]!r}")
            for target in destinations(f):
                if not raw_path(args.raw_root, args.locale, key, target['raw']).is_file():
                    raise ValueError(f"missing raw {key}/{target['raw']}")
            frame_extras = []
            for extra in f.get('extra_text', []):
                text_key = f"{f['file']}#{extra['key']}"
                text = headers.get(text_key, '')
                if not text.strip():
                    raise ValueError(f"{key}/{text_key}: missing localized extra text")
                job = extra_job(extra, text, args.locale, None)
                frame_extras.append((extra, job))
                extra_jobs.append(job)
            extras_by_frame[f['file']] = frame_extras
        plans.append((key, group, frames, jobs, size))
    if extra_jobs:
        extra_results = headline(extra_jobs)
        for job, result in zip(extra_jobs, extra_results):
            if not result['fits'] or result['size'] < job['minSize']:
                raise ValueError(f"extra text does not fit at min_size: {job['text']!r}")
    with tempfile.TemporaryDirectory() as tmp:
        for index, job in enumerate(extra_jobs):
            job['out'] = str(Path(tmp) / f'extra-{index}.png')
        if extra_jobs:
            extra_results = headline(extra_jobs)
            if not all(result['fits'] for result in extra_results):
                raise ValueError('extra text does not fit')
        for key, group, frames, jobs, size in plans:
            for i, job in enumerate(jobs):
                job.update(size=size, out=str(Path(tmp) / f'{i}.png'))
            rendered = headline(jobs)
            if not all(r['fits'] for r in rendered):
                raise ValueError(f'{key}: uniform header size does not fit')
            output = args.out / args.locale / key
            output.mkdir(parents=True, exist_ok=True)
            for frame, job in zip(frames, jobs):
                with Image.open(source(data, frame['base'])) as im:
                    canvas = im.convert('RGB')
                if canvas.size != tuple(group['canvas']):
                    raise ValueError(f"{frame['file']}: base size differs from canvas")
                plate = None
                if frame.get('plate'):
                    with Image.open(source(data, frame['plate'])) as im:
                        plate = im.convert('RGB')
                erase_header(canvas, frame['header_box'], plate)
                for target in destinations(frame):
                    with Image.open(raw_path(args.raw_root, args.locale, key, target['raw'])) as raw:
                        paste_screen(canvas, raw, target['rect'], target.get('radius', 0))
                with Image.open(job['out']) as overlay:
                    canvas.paste(overlay, tuple(frame['header_box'][:2]), overlay)
                for extra, extra_render in extras_by_frame[frame['file']]:
                    paint_extra_background(canvas, extra, plate)
                    with Image.open(extra_render['out']) as overlay:
                        canvas.paste(overlay, tuple(extra['box'][:2]), overlay)
                canvas.save(output / frame['file'], format='PNG', optimize=True)
            print(f'{args.locale}/{key}: {len(frames)} frames size={size:g}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f'reskin: {error}', file=sys.stderr)
        sys.exit(1)
