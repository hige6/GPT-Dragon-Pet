"""Render current pack for QA; this preview MP4 is opaque, pet PNGs retain alpha."""
from pathlib import Path
import argparse,json,subprocess
from PIL import Image,ImageDraw
import numpy as np
ap=argparse.ArgumentParser();ap.add_argument('--ffmpeg',required=True);a=ap.parse_args()
root=Path(__file__).resolve().parents[1];assets=root/'gpt-niang-usage/assets/dragon-video'
pack=json.loads((assets/'pack.json').read_text(encoding='utf-8'));report={};clips={}
for name,c in pack['clips'].items():
    frames=[]
    for i in range(c['count']):
        im=Image.open(assets/c['directory']/f'{i:04d}.png').convert('RGBA');assert im.size==(512,512)
        alpha=np.array(im.getchannel('A'));assert not alpha[0].any() and not alpha[-1].any() and not alpha[:,0].any() and not alpha[:,-1].any()
        frames.append(im)
    report[name]={'count':len(frames),'size':[512,512],'rgba':True,'transparentEdges':True,'playback':c['playback']}
    seq=frames[c.get('loopStart',0):] if c['playback']=='loop' else frames if c['playback']!='pingpong' else frames+frames[-2:0:-1]
    seq[0].save(root/f'video-{name}.webp',save_all=True,append_images=seq[1:],duration=83,loop=0,quality=85,method=2)
    clips[name]=frames
proc=subprocess.Popen([a.ffmpeg,'-v','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','800x600','-r','12','-i','pipe:0','-an','-c:v','libx264','-pix_fmt','yuv420p','-crf','20','-movflags','+faststart',str(root/'Dragon-Experience-Upgrade.mp4')],stdin=subprocess.PIPE)
for name,frames in clips.items():
    for im in frames[:48]:
        scene=Image.new('RGBA',(800,600),'#292335');scene.alpha_composite(im,(144,30));d=ImageDraw.Draw(scene)
        d.text((24,20),'GPT Dragon Pet / '+name,fill='#e6ddf2');proc.stdin.write(scene.convert('RGB').tobytes())
proc.stdin.close();assert proc.wait()==0
(root/'video-upgrade-validation.json').write_text(json.dumps({'clips':report,'frameCount':sum(c['count'] for c in report.values()),'passed':True},indent=2),encoding='utf-8')
print('All frames checked; current transparent WebPs and MP4 preview generated',flush=True)
