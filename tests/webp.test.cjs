const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{pathToFileURL}=require('node:url');
const repo=path.resolve(__dirname,'..');
test('Pro contains one trimmed clip with embedded timing backed by one WebP, with a PNG manager poster',()=>{
 const {pet,assets}=require('../scripts/pets.cjs').readPet(repo,'yuki-xlink-pro');
 assert.equal(JSON.parse(fs.readFileSync(path.join(repo,'pets/yuki-xlink-pro/pet.json'))).actions.work.frames,undefined);
 assert.equal(Object.keys(pet.actions).length,1);assert.equal(pet.actions.work.frames.length,74);
 assert.equal(pet.actions.work.frames.reduce((s,f)=>s+f.durationMs,0),3083);
 assert.equal(assets.size,2);assert.equal(assets.get('assets/laptop.webp').mime,'image/webp');
 assert.deepEqual(pet.actions.work.frames.map(f=>f.imageFrame),Array.from({length:74},(_,i)=>i));
});
test('animated player closes old frames, serializes decode, and releases in-flight result after disposal',async()=>{
 const {resolveFrame,transitionElapsed}=await import(pathToFileURL(path.join(repo,'player/timeline.mjs')).href);
 let now=0,callback,live=0,peak=0,inflight=0,maxInflight=0;
 const source=fs.readFileSync(path.join(repo,'player/player.mjs'),'utf8').replace(/^import[^\n]+\n/,'').replaceAll('export ','').replaceAll('import.meta.url',"'http://localhost/'");
 const create=new Function('resolveFrame','transitionElapsed','performance','document','requestAnimationFrame','cancelAnimationFrame','ResizeObserver','devicePixelRatio',source+';return createCanvasPlayer;')(resolveFrame,transitionElapsed,{now:()=>now},{hidden:false,addEventListener(){},removeEventListener(){}},fn=>{callback=fn;return 1;},()=>{},class{observe(){}disconnect(){}},1);
 const decoder={async decode(){inflight++;maxInflight=Math.max(maxInflight,inflight);await new Promise(r=>setImmediate(r));inflight--;live++;peak=Math.max(peak,live);let closed=false;return {image:{close(){assert.equal(closed,false);closed=true;live--;}}};}};
 const ctx={clearRect(){},save(){},translate(){},scale(){},drawImage(){},restore(){}};
 const canvas={getContext:()=>ctx,getBoundingClientRect:()=>({width:200,height:200}),dataset:{}};
 const frames=Array.from({length:240},(_,i)=>({file:'a.webp',imageFrame:i,durationMs:42}));
 const pet={defaultAction:'work',actions:{work:{frames}},bindings:{}};
 const player=create(canvas,pet,null,{images:[['a.webp',{decoder,first:{},width:720,height:720}]],onError:e=>{throw e;}});
 for(let i=0;i<500;i++){now=i*43;callback(now);await new Promise(r=>setImmediate(r));}
 assert.equal(maxInflight,1);assert.ok(peak<=2);assert.equal(live,1);
 now+=43;callback(now);player.dispose();await new Promise(r=>setImmediate(r));assert.equal(live,0);
});
