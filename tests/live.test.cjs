const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {applyLive,LIVE}=require('../scripts/apply-live.cjs');
test('live selection publishes fixed-size files; invalid packages preserve previous choice',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'codex-live-test-')),repo=path.resolve(__dirname,'..');
 try{
  fs.writeFileSync(path.join(root,'.codex-pets-runtime'),'');fs.writeFileSync(path.join(root,'codex-pets.json'),JSON.stringify({version:3}));
  const revision=applyLive(repo,root,'yuki');
  const file=path.join(root,LIVE,'selection.json'),pointer=path.join(root,LIVE,'revision.json');
  assert.equal(fs.statSync(file).size,64*1024*1024);assert.equal(fs.statSync(pointer).size,1024);
  const payload=JSON.parse(fs.readFileSync(file));assert.equal(payload.revision,revision);assert.equal(payload.pet.id,'yuki');assert.ok(Object.values(payload.images).every(x=>x.startsWith('data:image/png;base64,')));
  assert.throws(()=>applyLive(repo,root,'../escape'));assert.equal(JSON.parse(fs.readFileSync(pointer)).revision,revision);
  assert.throws(()=>applyLive(repo,root,'yuki','unknown'));assert.equal(JSON.parse(fs.readFileSync(pointer)).revision,revision);
  const rename=fs.renameSync;let attempts=0;
  fs.renameSync=(...args)=>{if(attempts++<2){const e=Error('sharing violation');e.code='EPERM';throw e;}return rename(...args);};
  try{applyLive(repo,root,'yuki','native');assert.ok(attempts>=3);}finally{fs.renameSync=rename;}
 assert.equal(JSON.parse(fs.readFileSync(file)).player,'native');
  fs.writeFileSync(path.join(root,'codex-pets.json'),JSON.stringify({version:1}));assert.throws(()=>applyLive(repo,root,'yuki'),/Install the live player/);
 }finally{assert.equal(path.dirname(root),os.tmpdir());assert.ok(path.basename(root).startsWith('codex-live-test-'));fs.rmSync(root,{recursive:true,force:true});}
});
