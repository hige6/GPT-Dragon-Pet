"""Build WPF PNG from an audited Codex v2 pack. Requires Python + Pillow, build only.
Layout/timing source: fywdy/chatgpt-chibi-pets tools/check-contract.py,
tools/verify-previews.py at d5bbb27c79e5c08e8b8ab44d4023cd35a67418e2.
The pet.json v2 flag alone does not describe frame timings.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

PACK = Path(__file__).resolve().parents[1] / 'gpt-niang-usage/assets/dragon-v5'
NAMES = ['idle', 'running-right', 'running-left', 'waving', 'jumping',
         'failed', 'waiting', 'running', 'review']
DURATIONS = [[280,110,110,140,140,320], [120]*7+[220], [120]*7+[220],
             [140]*3+[280], [140]*4+[280], [140]*7+[240],
             [150]*5+[260], [120]*5+[220], [150]*5+[280]]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate():
    pet = json.loads((PACK/'pet.json').read_text(encoding='utf-8-sig'))
    if pet.get('spriteVersionNumber') != 2 or pet.get('spritesheetPath') != 'spritesheet.webp':
        raise ValueError('Unsupported pack: expected audited v2 spritesheet.webp')
    im = Image.open(PACK/'spritesheet.webp')
    if im.size != (1536,2288) or im.mode != 'RGBA':
        raise ValueError('Expected 1536x2288 RGBA')
    unused = []
    for row, duration in enumerate(DURATIONS):
        used = len(duration) + (1 if row == 0 else 0)  # v2 neutral look at (0,6)
        for col in range(used,8):
            if im.crop((col*192,row*208,(col+1)*192,(row+1)*208)).getchannel('A').getbbox():
                unused.append([row,col])
    if unused:
        raise ValueError(f'Nontransparent reserved cells: {unused}')
    residue = sum(1 for r,g,b,a in im.getdata() if a == 0 and (r or g or b))
    if residue:
        raise ValueError(f'Transparent RGB residue: {residue}')
    return im

def build():
    im = validate()
    im.save(PACK/'spritesheet.png')
    im.crop((0,0,192,208)).save(PACK/'idle.png')
    layout = dict(version=2, columns=8, rows=11, cellWidth=192, cellHeight=208,
                  sourceSha256=digest(PACK/'spritesheet.webp'), pngSha256=digest(PACK/'spritesheet.png'),
                  animations={n:dict(row=i,durations=d) for i,(n,d) in enumerate(zip(NAMES,DURATIONS))},
                  states=dict(idle='idle',working='running',waiting='waiting',success='jumping',failure='failed',review='review'))
    (PACK/'atlas-layout.json').write_text(json.dumps(layout,indent=2),encoding='utf-8')
    assert Image.open(PACK/'spritesheet.png').tobytes() == im.tobytes()
    print('PASS: v2 dimensions, reserved cells, alpha residue, pixel-exact PNG, 57 animation frames + 17 look cells')

if __name__ == '__main__':
    build()
