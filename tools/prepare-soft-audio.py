"""Original quiet interaction cue, synthesized locally; no voice or external sample."""
from pathlib import Path
import math, struct, wave

root=Path(__file__).resolve().parents[1]
folder=root/'gpt-niang-usage/assets'
rate=22050
for name,seconds in [('press',.025),('release',.085)]:
    samples=[]
    for i in range(round(rate*seconds)):
        t=i/rate
        if name=='press':value=0
        else:
            attack=min(1,t/.006)
            tail=max(0,1-t/seconds)**2
            phase=2*math.pi*(620*t-900*t*t)
            value=.12*attack*tail*(math.sin(phase)+.14*math.sin(2*phase))
        samples.append(struct.pack('<h',round(32767*value)))
    with wave.open(str(folder/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
print('Prepared silent press and 85 ms quiet release cue')
