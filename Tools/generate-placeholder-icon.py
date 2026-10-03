#!/usr/bin/env python3
"""Render the temporary, unbranded development icon using only Python's stdlib.

No font, artwork, logo, trademark or image dependency is used. The geometric
remote is a placeholder, not an approved final brand. Run --check in CI to
verify that the tracked PNG exactly matches this editable source.
"""
from pathlib import Path
import argparse
import math
import struct
import zlib

SIZE = 1024
OUTPUT = Path(__file__).resolve().parent.parent / 'Resources/AppIcon/placeholder-app-icon.png'


def rounded_rect(x, y, cx, cy, width, height, radius):
    dx = abs(x - cx) - (width / 2 - radius)
    dy = abs(y - cy) - (height / 2 - radius)
    return math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - radius


def blend(base, color, distance):
    alpha = max(0.0, min(1.0, 0.5 - distance))
    return tuple(round(a * (1 - alpha) + b * alpha) for a, b in zip(base, color))


def render():
    rows = bytearray()
    for row in range(SIZE):
        rows.append(0)  # PNG filter: None.
        y = row + 0.5
        for column in range(SIZE):
            x = column + 0.5
            pixel = blend((0, 0, 0, 0), (49, 55, 65, 255), rounded_rect(x, y, 512, 512, 896, 896, 200))
            pixel = blend(pixel, (245, 247, 250, 255), rounded_rect(x, y, 512, 512, 298, 660, 142))
            pixel = blend(pixel, (69, 78, 91, 255), math.hypot(x - 512, y - 355) - 94)
            pixel = blend(pixel, (245, 247, 250, 255), math.hypot(x - 512, y - 355) - 41)
            for cy in (550, 691):
                pixel = blend(pixel, (69, 78, 91, 255), math.hypot(x - 512, y - cy) - 38)
            rows.extend(pixel)
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    result = render()
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != result:
            raise SystemExit('FAIL: placeholder PNG differs; regenerate with Tools/generate-placeholder-icon.py')
        print('PASS: deterministic unbranded icon matches its source')
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(result)
        print(OUTPUT)
