"""Reframe existing transparent assets; originals remain in the explicit backup.
No AI service, key or source-video mutation. Premultiplied blends avoid dark halos.
"""
import argparse, json, shutil
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

def blend(a,b,t):
    a=np.asarray(a,dtype=np.float32)/255; b=np.asarray(b,dtype=np.float32)/255
    alpha=a[:,:,3:]*(1-t)+b[:,:,3:]*t
    rgb=(a[:,:,:3]*a[:,:,3:]*(1-t)+b[:,:,:3]*b[:,:,3:]*t)/np.maximum(alpha,1e-8)
    return Image.fromarray(np.uint8(np.clip(np.concatenate((rgb,alpha),2)*255,0,255).round()))

def pose(im):
    a=np.array(im.resize((64,64)),dtype=np.float32)/255
    return np.concatenate((a[:,:,:3]*a[:,:,3:],a[:,:,3:]*2),2)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--backup',type=Path,required=True);args=ap.parse_args()
    root=Path(__file__).resolve().parents[1];out=root/'gpt-niang-usage/assets/dragon-video'
    source=args.backup/'dragon-video';pack=json.loads((source/'pack.json').read_text(encoding='utf-8'))
    if (pack['width'],pack['height'])!=(384,384):raise ValueError('Upgrade requires an original 384x384 backup')
    pending=out.parent/'dragon-video-upgrade';pending.mkdir(exist_ok=False)
    pack.update(width=512,height=512,displayReference=384,displayAnchor=[256,498],previousAnchor=[192,370])
    report={};tiles=[]
    for name,c in pack['clips'].items():
        frames=[];scale=.523/c['sourceTransform']['scale']
        # All characters use the same approximate source scale; fixed foot anchor.
        for i in range(c['count']):
            im=Image.open(source/c['directory']/f'{i:04d}.png').convert('RGBA')
            im=im.resize((round(384*scale),round(384*scale)),Image.Resampling.LANCZOS)
            frame=Image.new('RGBA',(512,512));frame.alpha_composite(im,(round(256-192*scale),round(498-370*scale)))
            frames.append(frame)
        detail={'sourceFrames':len(frames),'relativeScale':scale,'anchor':[256,498]}
        if name in ('idle','thinking'):
            poses=[pose(im) for im in frames];best=None
            # Prefer long forward sequences with similar boundary pose AND velocity.
            for start in range(0,min(25,len(frames)//4),2):
                for end in range(start+60,len(frames)-1,2):
                    gap=float(np.mean((poses[start]-poses[end])**2))
                    velocity=float(np.mean(((poses[start+1]-poses[start])-(poses[end]-poses[end-1]))**2))
                    score=gap+velocity*.35+.0003*(len(frames)-(end-start))/len(frames)
                    if best is None or score<best[0]:best=(score,start,end,gap)
            _,start,end,gap=best;frames=frames[start:end+1];n=6
            # Six-frame closure, then skip the already blended opening frames.
            for j in range(n):frames[-n+j]=blend(frames[-n+j],frames[j],(j+1)/n)
            c.update(playback='loop',loopStart=n)
            detail.update(selectedSourceRange=[start,end],boundaryPoseError=gap,blendFrames=n,forwardOnly=True)
        folder=pending/c['directory'];folder.mkdir()
        for i,im in enumerate(frames):im.save(folder/f'{i:04d}.png')
        frames[0].save(pending/f'{name}.png')
        bboxes=[im.getchannel('A').point(lambda v:255 if v>200 else 0).getbbox() for im in frames]
        c.update(count=len(frames),anchor=[256,498],normalization='512 canvas; common source scale 0.523; fixed foot anchor',bounds=[min(b[0] for b in bboxes),min(b[1] for b in bboxes),max(b[2] for b in bboxes),max(b[3] for b in bboxes)])
        detail.update(frames=len(frames),bounds=c['bounds'])
        assert all(im.getchannel('A').getbbox()[0]>0 and im.getchannel('A').getbbox()[2]<512 for im in frames),name
        report[name]=detail
        tile=Image.new('RGBA',(512,550),'#292335');tile.alpha_composite(frames[len(frames)//2],(0,0))
        ImageDraw.Draw(tile).text((12,520),name,fill='white');tiles.append(tile)
        print(name,detail,flush=True)
    (pending/'pack.json').write_text(json.dumps(pack,ensure_ascii=False,indent=2),encoding='utf-8')
    # Old frames have an independently verified full backup; retain current tree too.
    old=args.backup/'installed-dragon-video';out.rename(old);pending.rename(out)
    contact=Image.new('RGB',(512*4,550*2),'#292335')
    for i,tile in enumerate(tiles):contact.paste(tile.convert('RGB'),((i%4)*512,(i//4)*550))
    contact.save(root/'video-upgrade-contact.jpg',quality=92)
    (root/'video-upgrade-assets.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

if __name__=='__main__':main()
