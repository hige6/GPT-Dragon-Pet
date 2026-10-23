"""Validate distributed source and derived pixels without changing either file."""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
import importlib.util
spec=importlib.util.spec_from_file_location('atlas',root/'tools/prepare-atlas.py')
atlas=importlib.util.module_from_spec(spec)
spec.loader.exec_module(atlas)
im=atlas.validate()
png=Image.open(atlas.PACK/'spritesheet.png')
assert im.mode == png.mode == 'RGBA' and im.tobytes() == png.tobytes()
layout=json.loads((atlas.PACK/'atlas-layout.json').read_text())
assert layout['sourceSha256'] == atlas.digest(atlas.PACK/'spritesheet.webp')
assert layout['pngSha256'] == atlas.digest(atlas.PACK/'spritesheet.png')
for row,(name,durations) in enumerate(zip(atlas.NAMES,atlas.DURATIONS)):
    assert layout['animations'][name] == {'row':row,'durations':durations}
    for col in range(len(durations)):
        cell=png.crop((col*192,row*208,(col+1)*192,(row+1)*208))
        assert cell.getchannel('A').getbbox(),(name,col,'empty animation frame')
print('PASS: actual WebP v2 dimensions, RGBA, reserved cells, zero transparent RGB residue, PNG pixel identity, hashes, 57 nonempty animation cells, layout/timings')
