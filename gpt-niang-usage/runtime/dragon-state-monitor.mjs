// Reuse upstream tail/rotation/subagent handling. Export ONLY event kinds/timestamps.
// task_complete is a turn ending, never proof of overall task success.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {CompletionMonitor} from './completion-monitor.mjs';

export function parseDragonRecord(record,{sessionId='',since=0,seenTurns=null}={}){
  if(record?.type!=='event_msg')return null;
  const p=record.payload,kind=p?.type;
  if(!['task_started','task_complete','turn_complete','turn_aborted','task_failed'].includes(kind))return null;
  const at=typeof record.timestamp==='number'?record.timestamp:Date.parse(record.timestamp);
  if(!Number.isFinite(at)||at<since)return null;
  const turn=p.turn_id??record.turn_id;
  if(typeof turn!=='string'||!turn||turn.length>256)return null;
  const key=sessionId+'\0'+turn+'\0'+kind;
  if(seenTurns?.has(key))return null;
  if(seenTurns){seenTurns.add(key);if(seenTurns.size>4096)seenTurns.delete(seenTurns.values().next().value);}
  const failed=kind==='task_failed'||p.status==='failed';
  return {kind,sessionId,turn,at,state:kind==='task_started'?'working':failed?'failure':'idle'};
}
export class DragonActivity {
  constructor({maxSessions=512,staleMs=15*60*1000}={}){
    if(!Number.isSafeInteger(maxSessions)||maxSessions<1||!Number.isFinite(staleMs)||staleMs<1)throw new RangeError('Invalid activity retention limits');
    this.maxSessions=maxSessions;this.staleMs=staleMs;this.active=new Map();this.latest=new Map();this.lastAt=0;this.lastState='unknown';this.revision=0;this.incompleteUntil=0;
  }
  prune(now){
    for(const [id,at]of this.latest)if(now-at>this.staleMs){this.latest.delete(id);this.active.delete(id);}
    for(const [id,e]of this.active)if(now-e.at>this.staleMs)this.active.delete(id);
  }
  accept(e){
    this.prune(e.at);
    const previous=this.latest.get(e.sessionId)||0;if(e.at<previous)return;
    if(!this.latest.has(e.sessionId)&&this.latest.size>=this.maxSessions){
      // Prefer completed sessions. If a live session is evicted, idle cannot
      // imply that all observed work has ended until its retention expires.
      const victim=[...this.latest.keys()].find(id=>!this.active.has(id))??this.latest.keys().next().value;
      const dropped=this.active.get(victim);
      if(dropped)this.incompleteUntil=Math.max(this.incompleteUntil,dropped.at+this.staleMs);
      this.latest.delete(victim);this.active.delete(victim);
    }
    this.latest.delete(e.sessionId);
    this.latest.set(e.sessionId,e.at);
    if(e.state==='working')this.active.set(e.sessionId,{turn:e.turn,at:e.at});
    else if(this.active.get(e.sessionId)?.turn===e.turn)this.active.delete(e.sessionId);
    if(e.at>=this.lastAt){this.lastAt=e.at;this.lastState=e.state;}
    this.revision++;
  }
  snapshot(now=Date.now()){
    this.prune(now);
    const stale=this.lastAt===0||now-this.lastAt>this.staleMs,scopeIncomplete=now<this.incompleteUntil;
    return {version:1,source:'codex-local-events',state:this.active.size?'working':stale||scopeIncomplete?'unknown':this.lastState,
      activeCount:this.active.size,eventAt:this.lastAt,at:now,revision:this.revision,
      // No session IDs, paths, prompts, replies, tokens or raw payloads in snapshot.
      scope:'all-observed-non-subagent-turns',scopeIncomplete,waitingSupported:false,taskSuccessSupported:false};
  }
}
function run(){
  const destination=process.argv[2];if(!destination)throw new Error('State destination required');
  const activity=new DragonActivity();
  function save(){const temp=destination+'.'+process.pid+'.tmp';try{fs.writeFileSync(temp,JSON.stringify(activity.snapshot()));fs.renameSync(temp,destination);}catch{try{fs.unlinkSync(temp);}catch{}}}
  const monitor=new CompletionMonitor({intervalMs:2000,parseRecord:parseDragonRecord,onNotification:e=>{activity.accept(e);save();}});
  monitor.start();save();const timer=setInterval(save,5000);
  process.stdin.resume();const stop=()=>{clearInterval(timer);monitor.stop();process.exit(0);};
  process.stdin.on('end',stop);process.on('SIGTERM',stop);
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))run();
