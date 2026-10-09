const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {readPet}=require('./pets.cjs');
const LIVE='resources/app.asar.unpacked/webview/assets/codex-pets';
function atomic(file,data,size){fs.mkdirSync(path.dirname(file),{recursive:true});const temp=file+'.'+crypto.randomUUID()+'.tmp';try{const raw=Buffer.from(JSON.stringify(data));if(size&&raw.length>size)throw Error('Pet package exceeds live capacity (64 MiB JSON).');const out=size?Buffer.alloc(size,32):raw;if(size)raw.copy(out);fs.writeFileSync(temp,out);const deadline=Date.now()+5000;for(;;){try{fs.renameSync(temp,file);break;}catch(e){if(!['EPERM','EACCES','EBUSY'].includes(e.code)||Date.now()>=deadline)throw e;Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,100);}}}finally{if(fs.existsSync(temp))fs.unlinkSync(temp);}}
function applyLive(repo,runtime,id,player='canvas'){
 if(/windowsapps/i.test(runtime)||!['.codex-pets-runtime','.yuki-player-lab'].some(m=>fs.existsSync(path.join(runtime,m))))throw Error('Expected marked separate runtime');
 const marker=JSON.parse(fs.readFileSync(path.join(runtime,'codex-pets.json'),'utf8'));
 if(marker.version!==3)throw Error('Install the live player first');
 if(!['canvas','native'].includes(player))throw Error('Unsupported player');
 const revision=crypto.randomUUID(),selection={version:1,revision,player};
 if(player==='canvas'){
 const {pet,assets}=readPet(repo,id);selection.pet=pet;selection.images={};
 for(const [name,asset]of assets)selection.images[name]='data:image/png;base64,'+fs.readFileSync(asset.file).toString('base64');
 }
 // Publish pointer last: readers never observe half-written JSON.
 atomic(path.join(runtime,LIVE,'selection.json'),selection,64*1024*1024);
 atomic(path.join(runtime,LIVE,'revision.json'),{revision},1024);
 atomic(path.join(runtime,'codex-pets.json'),{...marker,pet:id,player,revision});
 return revision;
}
if(require.main===module){try{console.log('Published live selection: '+applyLive(path.resolve(__dirname,'..'),path.resolve(process.argv[2]),process.argv[3],process.argv[4]||'canvas'));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={applyLive,LIVE};
