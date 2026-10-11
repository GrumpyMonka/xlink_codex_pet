const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
// Exercise the real maintenance loop with an existing authenticated connection.
async function runLoop(active){let ticks=0,spawns=0,writes=0;const source=fs.readFileSync(path.join(__dirname,'../scripts/toolbar-bridge.cjs'),'utf8');
 const config=()=>JSON.stringify({enabled:ticks<4,pet:'yuki',player:'canvas'});
 const fakeFs={readFileSync(p,encoding){if(p.endsWith('main-settings.json'))return config();return encoding?'/* toolbar */':Buffer.from('/* toolbar */')},writeFileSync(){writes++},appendFileSync(){}};
 const fakeCp={spawn(){spawns++;return {stdout:{on(){}},stderr:{on(){}},on(){}}}};
 const context={require(n){if(n==='node:fs')return fakeFs;if(n==='node:path')return path;if(n==='node:child_process')return fakeCp;if(n==='./main-session.cjs')return {verifyMain(){throw Error('unexpected verification')}};if(n==='./playback.cjs')return {readSpeeds:()=>({})};throw Error(n)},__dirname:path.join(__dirname,'../scripts'),process:{pid:123},console,WebSocket:{OPEN:1},setInterval(){return 1},clearInterval(){},setTimeout(fn){ticks++;queueMicrotask(fn);return 1},clearTimeout(){},URL,Date};
 const injected=source.replace('(async()=>{while(enabled()){',`connection={readyState:1,close(){}};ensureTray=()=>{};send=async(method,params)=>({result:{value:{toolbar:true,active:${active},pet:'yuki'}}});(async()=>{while(enabled()){`);
 await vm.runInNewContext(injected,context);return {spawns,writes};
}
test('healthy heartbeat never launches PowerShell maintenance',async()=>{const r=await runLoop(true);assert.equal(r.spawns,0);assert.equal(r.writes,4)});
test('missing player triggers one recovery worker without spawning overlapping workers',async()=>{const r=await runLoop(false);assert.equal(r.spawns,1);assert.equal(r.writes,4)});
