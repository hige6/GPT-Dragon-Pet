"""Convert user-supplied chroma-key clips to fixed-anchor RGBA frame packs.
No remote generation, no credentials, no modification of input files.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--downloads', type=Path)
    ap.add_argument('--idle', type=Path)
    ap.add_argument('--append-extra', type=Path, help='Append the three additional user clips from this directory')
    ap.add_argument('--ffmpeg', required=True)
    args=ap.parse_args()
    root=Path(__file__).resolve().parents[1]
    out=root/'gpt-niang-usage/assets/dragon-video'
    out.mkdir(parents=True,exist_ok=True)
    if not args.append_extra and (not args.downloads or not args.idle):ap.error('Provide --downloads and --idle, or --append-extra')
    sources=[] if args.append_extra else [('idle','待机',args.idle,True),
        ('success','得意庆祝',args.downloads/'生成龙娘动作制作视频 (1).mp4',False),
        ('click','傲娇回应',args.downloads/'生成龙娘动作制作视频 (2).mp4',False),
        ('thinking','托腮思考',args.downloads/'生成龙娘动作制作视频 (3).mp4',True)]
    fps=12; canvas=(384,384); previews=[]; manifest={'version':1,'fps':fps,'width':384,'height':384,
        'default':'idle','states':{'idle':'idle','working':'thinking','waiting':'thinking','success':'success','failure':'atlas','review':'thinking'},
        'notes':{'working':'复用托腮思考素材','waiting':'暂借思考素材，非专门等待动作','failure':'使用原 v5 失败图集','review':'复用思考素材'},'clips':{}}
    if args.append_extra:
        manifest=json.loads((out/'pack.json').read_text(encoding='utf-8'))
        canvas=(manifest['width'],manifest['height'])
        sources=[('tsundere-strong','超级傲娇',args.append_extra/'超级傲娇.mp4',False),
            ('rabbit-ears','兔耳装扮',args.append_extra/'兔儿.mp4',False),
            ('scarf','围巾装扮',args.append_extra/'围巾.mp4',False)]
    for clip,label,path,loop in sources:
        measured=None;source_top_touch=0
        if args.append_extra:
            probe=subprocess.Popen([args.ffmpeg,'-v','error','-i',str(path),'-vf',f'fps={fps}','-f','rawvideo','-pix_fmt','rgb24','pipe:1'],stdout=subprocess.PIPE)
            boxes=[]
            while True:
                raw=probe.stdout.read(1280*720*3)
                if not raw:break
                if len(raw)!=1280*720*3:raise ValueError('Unexpected input size')
                x=np.frombuffer(raw,dtype=np.uint8).reshape(720,1280,3).astype(np.float32)
                g=x[:,:,1];ratio=(g-np.maximum(x[:,:,0],x[:,:,2]))/np.maximum(g,1)
                mask=ratio<.09;mask[:,:260]=False;mask[:,1080:]=False
                source_top_touch+=int(mask[0,:].any())
                ys,xs=np.where(mask);boxes.append((int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())+1))
            probe.stdout.close()
            if probe.wait()!=0:raise RuntimeError('Bounds probe failed')
            first=boxes[0];center=(first[0]+first[2])/2;bottom=first[3]
            x0=min(b[0] for b in boxes);x1=max(b[2] for b in boxes);y0=min(b[1] for b in boxes)
            scale=min(346/(bottom-first[1]),174/max(center-x0,x1-center),358/(bottom-y0))
            if canvas==(512,512):
                scale=.523
                if (max(center-x0,x1-center)*scale>248 or (bottom-y0)*scale>490):
                    raise ValueError('Clip exceeds the expanded canvas at normal character size; extend the renderer canvas explicitly')
                measured=(scale,256-center*scale,498-bottom*scale)
            else:measured=(scale,192-center*scale,370-bottom*scale)
        folder=out/clip;folder.mkdir(exist_ok=True)
        proc=subprocess.Popen([args.ffmpeg,'-v','error','-i',str(path),'-vf',f'fps={fps}',
            '-f','rawvideo','-pix_fmt','rgb24','pipe:1'],stdout=subprocess.PIPE)
        frames=[];i=0;scale=None;bounds=[]
        if measured:scale,left,top=measured
        while True:
            data=proc.stdout.read(1280*720*3)
            if not data:break
            if len(data)!=1280*720*3:raise ValueError('Incomplete frame')
            rgb=np.frombuffer(data,dtype=np.uint8).reshape(720,1280,3).copy()
            f=rgb.astype(np.float32);r,g,b=f[:,:,0],f[:,:,1],f[:,:,2]
            ratio=(g-np.maximum(r,b))/np.maximum(g,1)
            alpha=np.clip((.29-ratio)/.20,0,1)
            # Only the central full-body region belongs to the pet; preserve originals separately.
            alpha[:,:260]=0;alpha[:,1080 if args.append_extra else 1030:]=0
            alpha[:2,:]=0;alpha[710:,:]=0
            ys,xs=np.nonzero(alpha>.95)
            if not len(xs):raise ValueError('No character foreground')
            if scale is None:
                xcenter=(int(xs.min())+int(xs.max()))/2
                bottom=int(ys.max())+1
                scale=346/(bottom-int(ys.min()))
                # Constant transform per clip; never recenter each frame.
                left=192-xcenter*scale;top=370-bottom*scale
            # Suppress green spill only; retain original red/blue and alpha.
            rgb[:,:,1]=np.minimum(rgb[:,:,1],np.maximum(rgb[:,:,0],rgb[:,:,2]))
            rgba=np.dstack((rgb,(alpha*255).round().astype(np.uint8)))
            im=Image.fromarray(rgba).resize((round(1280*scale),round(720*scale)),Image.Resampling.LANCZOS)
            frame=Image.new('RGBA',canvas)
            frame.alpha_composite(im,(round(left),round(top)))
            bbox=frame.getchannel('A').point(lambda v:255 if v>200 else 0).getbbox();bounds.append(bbox)
            frame.save(folder/f'{i:04d}.png',optimize=False)
            frames.append(frame);i+=1
        proc.stdout.close()
        if proc.wait()!=0:raise RuntimeError('ffmpeg decode failed')
        if not frames:raise ValueError('Empty clip')
        # Continuous states run forward then backward: no hard last-to-first splice.
        manifest['clips'][clip]={'label':label,'directory':clip,'count':i,'fps':fps,
            'loop':loop,'playback':'pingpong' if loop else 'once','returnTo':'idle',
            'sourceFile':path.name,'sourceSha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'anchor':[256,498] if canvas==(512,512) else [192,370], 'sourceTransform':{'scale':scale,'left':left,'top':top},
            'bounds':[min(x[0] for x in bounds),min(x[1] for x in bounds),max(x[2] for x in bounds),max(x[3] for x in bounds)]}
        if args.append_extra:
            manifest['clips'][clip]['sourceTopTouchFrames']=source_top_touch
            manifest['clips'][clip]['normalization']='Fixed foot anchor; whole-clip bounds constrained to canvas'
        frames[0].save(out/f'{clip}.png')
        seq=frames+frames[-2:0:-1] if loop else frames
        seq[0].save(root/f'video-{clip}.webp',save_all=True,append_images=seq[1:],duration=round(1000/fps),loop=0,quality=85,method=2)
        previews.append((label,frames))
        print(clip,'frames',i,'bounds',manifest['clips'][clip]['bounds'],flush=True)
    temp=out/'pack.pending.json';temp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(out/'pack.json')
    # Side-by-side light/dark QA samples, showing keyed edges at native output size.
    contact=Image.new('RGB',(384*len(previews),410*2),'#eeeaf5');draw=ImageDraw.Draw(contact)
    for j,(_,frames) in enumerate(previews):
        im=frames[len(frames)//2].resize((384,384),Image.Resampling.LANCZOS)
        for row,bg in enumerate(('#eeeaf5','#242135')):
            tile=Image.new('RGBA',canvas,bg);tile.alpha_composite(im)
            contact.paste(tile.convert('RGB'),(j*384,row*410));draw.text((j*384+10,row*410+386),sources[j][0],fill='#8877aa')
    contact.save(root/('video-new-actions-preview.jpg' if args.append_extra else 'video-pack-preview.jpg'),quality=94)
    # Portable visual showcase; no alpha claim for MP4 preview.
    proc=subprocess.Popen([args.ffmpeg,'-v','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','640x480','-r',str(fps),'-i','pipe:0',
        '-an','-c:v','libx264','-pix_fmt','yuv420p','-crf','20','-movflags','+faststart',str(root/('Dragon-New-Actions.mp4' if args.append_extra else 'Dragon-Showcase.mp4'))],stdin=subprocess.PIPE)
    for j,(_,frames) in enumerate(previews):
        for im in frames[:fps*5]:
            scene=Image.new('RGBA',(640,480),'#242135');scene.alpha_composite(im.resize((384,384),Image.Resampling.LANCZOS),(128,52));d=ImageDraw.Draw(scene)
            d.text((20,18),'GPT Dragon Pet / '+sources[j][0],fill='#ddd2f5')
            proc.stdin.write(scene.convert('RGB').tobytes())
    proc.stdin.close()
    if proc.wait()!=0:raise RuntimeError('Showcase encode failed')
    print('Pack and preview complete')

if __name__=='__main__':main()
