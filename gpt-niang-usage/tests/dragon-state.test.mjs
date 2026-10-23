import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {parseDragonRecord,DragonActivity} from '../runtime/dragon-state-monitor.mjs';
import {CompletionMonitor} from '../runtime/completion-monitor.mjs';
const now=Date.now();
const record=(kind,turn='t1',at=now,extra={})=>({type:'event_msg',timestamp:new Date(at).toISOString(),payload:{type:kind,turn_id:turn,...extra}});
test('reply/task end is idle, never success; errors and chat content are not exported',()=>{
  for(const kind of ['task_complete','turn_complete']){
    const e=parseDragonRecord(record(kind,'t',now,{last_agent_message:'PRIVATE',summary:'PRIVATE'}));
    assert.equal(e.state,'idle');assert.ok(!JSON.stringify(e).includes('PRIVATE'));
  }
  assert.equal(parseDragonRecord(record('task_started')).state,'working');
  assert.equal(parseDragonRecord(record('turn_aborted')).state,'idle');
  assert.equal(parseDragonRecord(record('task_failed')).state,'failure');
  assert.equal(parseDragonRecord(record('agent_message')),null);
  assert.equal(parseDragonRecord(record('token_count')),null);
});
test('time boundary, malformed records and duplicate event kinds fail closed',()=>{
  const opts={since:now,seenTurns:new Set(),sessionId:'s'};
  assert.equal(parseDragonRecord(record('task_started','t',now-1),opts),null);
  assert.ok(parseDragonRecord(record('task_started'),opts));
  assert.equal(parseDragonRecord(record('task_started'),opts),null);
  assert.ok(parseDragonRecord(record('task_complete'),opts));
  assert.equal(parseDragonRecord(record('task_started',''),opts),null);
});
test('concurrent sessions and late old-turn endings cannot stop another active turn',()=>{
  const a=new DragonActivity();
  const send=(kind,session,turn,at)=>a.accept(parseDragonRecord(record(kind,turn,at),{sessionId:session}));
  send('task_started','a','1',now);send('task_started','b','2',now+1);
  send('task_complete','a','1',now+2);assert.equal(a.snapshot(now+3).state,'working');
  send('task_started','b','3',now+4);send('task_complete','b','2',now+5);
  assert.equal(a.snapshot(now+6).state,'working');
  send('task_complete','b','3',now+7);assert.equal(a.snapshot(now+8).state,'idle');
  const safe=JSON.stringify(a.snapshot(now+8));assert.ok(!safe.includes('sessionId'));assert.ok(!safe.includes('turnId'));
});
test('missing heartbeat events expire to unknown instead of fabricated completion',()=>{
  const a=new DragonActivity();a.accept(parseDragonRecord(record('task_started'),{sessionId:'a'}));
  assert.equal(a.snapshot(now+16*60*1000).state,'unknown');
  assert.equal(a.snapshot(now+16*60*1000).taskSuccessSupported,false);
});
test('completed session history stays bounded during long runs',()=>{
  const a=new DragonActivity({maxSessions:32});
  for(let i=0;i<5000;i++)a.accept({sessionId:'session-'+i,turn:'t',at:now+i,state:'idle'});
  assert.equal(a.latest.size,32);assert.equal(a.active.size,0);
  assert.equal(a.snapshot(now+5000).state,'idle');
});
test('retention prefers completed sessions over ongoing work',()=>{
  const a=new DragonActivity({maxSessions:2});
  a.accept({sessionId:'active',turn:'a',at:now,state:'working'});
  a.accept({sessionId:'finished',turn:'b',at:now+1,state:'idle'});
  a.accept({sessionId:'new',turn:'c',at:now+2,state:'working'});
  assert.ok(a.active.has('active'));assert.ok(!a.latest.has('finished'));
  assert.equal(a.snapshot(now+3).scopeIncomplete,false);
});
test('overflow of live sessions becomes unknown rather than false idle',()=>{
  const a=new DragonActivity({maxSessions:1,staleMs:1000});
  a.accept({sessionId:'untracked',turn:'a',at:now,state:'working'});
  a.accept({sessionId:'tracked',turn:'b',at:now+1,state:'working'});
  a.accept({sessionId:'tracked',turn:'b',at:now+2,state:'idle'});
  assert.equal(a.latest.size,1);assert.equal(a.active.size,0);
  assert.equal(a.snapshot(now+3).state,'unknown');
  assert.equal(a.snapshot(now+3).scopeIncomplete,true);
  assert.equal(a.snapshot(now+1001).state,'idle');
});
test('expired session identifiers are released from both maps',()=>{
  const a=new DragonActivity({staleMs:1000});
  a.accept({sessionId:'expired',turn:'t',at:now,state:'working'});
  assert.equal(a.snapshot(now+1001).state,'unknown');
  assert.equal(a.latest.size,0);assert.equal(a.active.size,0);
  assert.throws(()=>new DragonActivity({maxSessions:0}),RangeError);
});
test('real file tail integration ignores history/subagents and observes new start/end',()=>{
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'dragon-events-'));const root=path.join(temp,'sessions');fs.mkdirSync(root);
  const file=path.join(root,'main.jsonl');const sub=path.join(root,'sub.jsonl');
  const line=v=>JSON.stringify(v)+'\n';
  fs.writeFileSync(file,line({type:'session_meta',payload:{source:'cli'}})+line(record('task_started','old',now-10000)));
  fs.writeFileSync(sub,line({type:'session_meta',payload:{source:{subagent:{}}}}));
  const events=[];const monitor=new CompletionMonitor({codexHome:temp,parseRecord:parseDragonRecord,since:now,onNotification:e=>events.push(e)});
  try{
    monitor.scan(true);assert.equal(events.length,0);
    fs.appendFileSync(file,line(record('task_started')));fs.appendFileSync(sub,line(record('task_started')));
    monitor.scan();assert.equal(events.length,1);assert.equal(events[0].state,'working');
    fs.appendFileSync(file,line(record('task_complete','t1',now+1)));monitor.scan();assert.equal(events.at(-1).state,'idle');
  }finally{monitor.stop();fs.rmSync(temp,{recursive:true,force:true});}
});
