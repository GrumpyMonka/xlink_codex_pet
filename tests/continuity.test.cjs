const test=require('node:test'),assert=require('node:assert/strict');
test('cup state changes preserve raising and lowering frame plus fractional progress',async()=>{
 const {transitionElapsed,resolveFrame}=await import('../player/timeline.mjs');
 const frames=[100,200,150].map((durationMs,i)=>({file:'frame-'+i+'.png',durationMs}));const pet={defaultAction:'idle',actions:{idle:{continuityGroup:'cup',frames},waiting:{continuityGroup:'cup',frames:frames.map(f=>({...f,durationMs:f.durationMs*2}))},work:{frames:[{file:'work.png',durationMs:100}]}},bindings:{idle:{action:'idle'},waiting:{action:'waiting'}}};
 for(const [from,to]of [['idle','waiting'],['waiting','idle']]){
  const source=pet.actions[from],target=pet.actions[to];let offset=0;
  for(let i=0;i<source.frames.length;i++){
   const elapsed=offset+source.frames[i].durationMs*.4;
   const next=transitionElapsed(source,target,elapsed);
   assert.equal(resolveFrame(pet,to,next).index,i);
   const roundTrip=transitionElapsed(target,source,next);assert(Math.abs(roundTrip-elapsed)<.001);
   offset+=source.frames[i].durationMs;
  }
 }
});
test('unrelated actions still start from their initial pose',async()=>{
 const {transitionElapsed}=await import('../player/timeline.mjs');const frames=[100,200,150].map((durationMs,i)=>({file:'frame-'+i+'.png',durationMs}));const pet={defaultAction:'idle',actions:{idle:{continuityGroup:'cup',frames},waiting:{continuityGroup:'cup',frames:frames.map(f=>({...f,durationMs:f.durationMs*2}))},work:{frames:[{file:'work.png',durationMs:100}]}},bindings:{idle:{action:'idle'},waiting:{action:'waiting'}}};
 assert.equal(transitionElapsed(pet.actions.idle,pet.actions.work,2000),0);
});
