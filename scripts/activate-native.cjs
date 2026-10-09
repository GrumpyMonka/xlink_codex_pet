const fs=require('fs'),path=require('path');
async function activate(repo,id,port,main=false){
 if(typeof WebSocket!=='function')throw Error('Node.js 22+ required');
 if(!/^[a-z0-9][a-z0-9-]{0,63}$/.test(id)||!Number.isInteger(port)||port<1||port>65535)throw Error('Invalid request');
 const settings=main?null:JSON.parse(fs.readFileSync(path.join(repo,'.runtime/settings.json'),'utf8').replace(/^\uFEFF/,''));
 const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`,{signal:AbortSignal.timeout(5000)})).json();
 const pages=targets.filter(t=>t.type==='page'&&t.url.startsWith('app://-/index.html'));if(!pages.length)throw Error('Codex not ready');
 async function run(page,expression){const url=new URL(page.webSocketDebuggerUrl);if(url.hostname!=='127.0.0.1'||url.protocol!=='ws:')throw Error('Non-local endpoint');const ws=new WebSocket(url);try{return await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Codex selection timeout')),30000);function done(err,v){clearTimeout(timer);err?reject(err):resolve(v);}ws.addEventListener('error',()=>done(Error('Cannot connect to managed Codex')));ws.addEventListener('open',()=>ws.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{expression,awaitPromise:true,returnByValue:true}})));ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id!==1)return;const error=m.error?.message||m.result?.exceptionDetails?.exception?.description||m.result?.exceptionDetails?.text;done(error?Error(error):null,m.result?.result?.value);});});}finally{ws.close();}}
 for(const page of pages)await run(page,`(async()=>{const m=await import('app://-/assets/app-shared-40678a67f0e3.js');await m.aj.clientCoordination.invalidateQueryCache({queryKey:['custom-avatars']});return true;})()`);
 const result=await run(pages.find(p=>p.url==='app://-/index.html')||pages[0],`(async()=>{
 const m=await import('app://-/assets/app-shared-40678a67f0e3.js');const local=await m.aj.customAvatars.load();
 const expected=${JSON.stringify((main?path.join(require('os').homedir(),'.codex','pets'):path.resolve(settings.profile,'codex-home','pets')))};
 if(local.avatarDirectory.replaceAll('\\\\','/').toLowerCase()!==expected.replaceAll('\\\\','/').toLowerCase())throw Error('Wrong Codex profile');
 const pet=local.avatars.find(p=>p.id===${JSON.stringify('custom:xlink-manager-'+id)});if(!pet)throw Error('Installed pet missing in Codex');
 await m.aj.settings.write(m.y1t.selectedAvatarId.key,pet.id);await m.aj.settings.write(m.y1t.petVisible.key,true);
 const selected=await m.aj.settings.read(m.y1t.selectedAvatarId.key);if(selected.effective!==pet.id)throw Error('Selection not confirmed');
 await m.aj.clientCoordination.invalidateQueryCache({queryKey:['custom-avatars']});return {confirmed:true,localId:pet.id,name:pet.displayName,selectedId:selected.effective};})()`);
 fs.writeFileSync(path.join(repo,'.runtime/native-selection.json'),JSON.stringify({...result,confirmedAt:new Date().toISOString()},null,2));return result;
}
if(require.main===module)activate(path.resolve(__dirname,'..'),process.argv[2],Number(process.argv[3]),process.argv.includes('--main')).then(r=>console.log(JSON.stringify(r))).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={activate};
