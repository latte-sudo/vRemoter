#!/usr/bin/env python3
"""Source/geometry guard usable without macOS; not a Swift build or UI render."""
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
layout = (root / 'Sources/vRemote/ChromecastMappingLayout.swift').read_text()
canvas = (root / 'Sources/vRemote/ChromecastMappingCanvas.swift').read_text()
console = (root / 'Sources/vRemote/ChromecastConsoleView.swift').read_text()
rows = re.findall(r'\.init\(id: "([^"]+)", right: (true|false), row: (\d+), x: ([.\d]+), y: ([.\d]+)\)', layout)
assert len(rows) == len({r[0] for r in rows}) == 15
assert [r[0] for r in rows if r[1] == 'false'] == ['03','05','04','0B','0A','0E','01']
assert [r[0] for r in rows if r[1] == 'true'] == ['07','06','0C','0D','voice','08','0F','11']
height = float(re.search(r'let height: CGFloat = (\d+)', layout)[1])
card_height = float(re.search(r'let cardHeight: CGFloat = (\d+)', layout)[1])
stride = float(re.search(r'let rowStride: CGFloat = (\d+)', layout)[1])
for width in [760,800,924,1020,1400]:
    card = min(300, max(210, (width-324)/2))
    photo = max(120, min(300, width-2*card-24))
    assert (width-photo)/2 > card+7
    assert stride >= card_height
    for _, _, row, x, y in rows:
        assert int(row)*stride+card_height <= height
        assert 0 < float(x) < 1 and 0 < float(y) < 1
assert 'HStack(spacing: 4)' in canvas
assert 'VStack(spacing: 1)' in canvas
assert 'max(760, proxy.size.width)' in canvas
assert 'ScrollView(.horizontal' in canvas
assert 'if placement.id == "voice"' in canvas
assert 'ChromecastGestureEditor(button: button, gesture: gesture)' in console
assert 'scroll.scrollTo("chromecast-inline-editor", anchor: .top)' in console
print('Mapping source and geometry checks passed (not native rendering)')
