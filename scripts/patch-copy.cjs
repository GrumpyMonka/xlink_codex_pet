// Patches only a marked laboratory copy, never the installed Store application.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(process.argv[2]||''),repo=path.resolve(__dirname,'..');
const {readPet}=require('./pets.cjs');
const {pet,assets}=readPet(repo,process.argv[3]||'vpet');
if(!process.argv[2] || /windowsapps/i.test(root) || !['.codex-pets-runtime','.yuki-player-lab'].some(m=>fs.existsSync(path.join(root,m)))) throw Error('Expected marked separate Codex copy');
const filename=path.join(root,'resources/app.asar'),backup=path.join(root,'resources/app.original.asar');
const fd=fs.openSync(fs.existsSync(backup)?backup:filename,'r'),pre=Buffer.alloc(16);fs.readSync(fd,pre,0,16,0);
const base=8+pre.readUInt32LE(4),json=Buffer.alloc(pre.readUInt32LE(12));fs.readSync(fd,json,0,json.length,16);
const header=JSON.parse(json),entries=[];
function walk(v,p=''){for(const[n,item]of Object.entries(v.files||{})){const q=p?p+'/'+n:n;if(item.files)walk(item,q);else entries.push({q,item,oldOffset:item.offset});}}
walk(header);
function read(q){const v=entries.find(e=>e.q===q)?.item;if(!v||v.unpacked)throw Error('Missing '+q);const b=Buffer.alloc(v.size);fs.readSync(fd,b,0,b.length,base+Number(v.offset));return b;}
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const executable=path.join(root,'ChatGPT.exe'),exe=fs.readFileSync(fs.existsSync(executable+'.original')?executable+'.original':executable),oldHash=sha(json);
if(oldHash!=='93f356e95b578a18d8529ebf7ae7554bdf20cd6974983234baf7a8a60dad37e3')throw Error('Unsupported original app archive. Installed Codex was not changed.');
const hashPosition=exe.indexOf(oldHash);
if(hashPosition<0 || exe.indexOf(oldHash,hashPosition+1)!==-1)throw Error('Unknown executable integrity record');
const shared='webview/assets/app-initial-25361a10f2bf.js';
if(sha(read(shared))!=='bddf0e4e79918f7157682015c598b97eb833553c036026004555f88fa0cb9d3b')throw Error('Unsupported Codex build');
const target='webview/assets/avatar-mascot-button-a626ddede376.js';
let js=read(target).toString();
const needle='(0,k.jsx)(h,{assetMap:f,className:';
if(js.split(needle).length!==2)throw Error('Renderer boundary changed');
js=js.replace(needle,'(0,k.jsx)(CustomPetSwitch,{assetMap:f,className:');
js='import {createCanvasPlayer as createCustomPlayer} from "./codex-pets/player.mjs";\n'+js+'\n'+fs.readFileSync(path.join(repo,'player/adapter.js.txt'),'utf8');
const changed=new Map([[target,Buffer.from(js)]]);
const resources=new Map(['player.mjs','timeline.mjs'].map(name=>[name,fs.readFileSync(path.join(repo,'player',name))]));
resources.set('selection.json',Buffer.from('{}'));resources.set('revision.json',Buffer.from('{}'));
for(const [name,b] of resources){
  const q='webview/assets/codex-pets/'+name;
  changed.set(q,b);let node=header;const parts=q.split('/');const leaf=parts.pop();for(const part of parts){node.files??={};node.files[part]??={files:{}};node=node.files[part];}node.files[leaf]=name.endsWith('.json')?{size:name==='selection.json'?64*1024*1024:1024,unpacked:true}:{size:b.length,offset:'0'};
  if(name.endsWith('.json')){const external=path.join(root,'resources/app.asar.unpacked',q);fs.mkdirSync(path.dirname(external),{recursive:true});if(!fs.existsSync(external))fs.writeFileSync(external,b);}
  entries.push({q,item:node.files[leaf]});
}
let offset=0;for(const entry of entries){const v=entry.item;if(v.unpacked||v.link)continue;const b=changed.get(entry.q);if(b){v.size=b.length;const blockSize=4*1024*1024,blocks=[];for(let i=0;i<b.length;i+=blockSize)blocks.push(sha(b.subarray(i,i+blockSize)));v.integrity={algorithm:'SHA256',hash:sha(b),blockSize,blocks};}v.offset=String(offset);offset+=v.size;}
const raw=Buffer.from(JSON.stringify(header)),padded=Math.ceil(raw.length/4)*4,head=Buffer.alloc(16+padded);
head.writeUInt32LE(4,0);head.writeUInt32LE(8+padded,4);head.writeUInt32LE(4+padded,8);head.writeUInt32LE(raw.length,12);raw.copy(head,16);
const temp=filename+'.codex-pets-'+process.pid+'-'+Date.now()+'.tmp',out=fs.openSync(temp,'wx');fs.writeSync(out,head);
const chunk=Buffer.alloc(8*1024*1024);
try{for(const entry of entries){const v=entry.item;if(v.unpacked||v.link)continue;const b=changed.get(entry.q);if(b){fs.writeSync(out,b);continue;}let left=v.size,pos=base+Number(entry.oldOffset);while(left){const n=fs.readSync(fd,chunk,0,Math.min(left,chunk.length),pos);if(!n)throw Error('Truncated ASAR');fs.writeSync(out,chunk,0,n);pos+=n;left-=n;}}}finally{fs.closeSync(fd);fs.closeSync(out);}
if(!fs.existsSync(backup))fs.copyFileSync(filename,backup);
if(!fs.existsSync(executable+'.original'))fs.copyFileSync(executable,executable+'.original');
const previous=filename+'.pre-pets',previousExe=executable+'.pre-pets';fs.copyFileSync(filename,previous);fs.copyFileSync(executable,previousExe);
try{fs.copyFileSync(temp,filename);exe.write(sha(raw),hashPosition,64,'ascii');fs.writeFileSync(executable,exe);
fs.writeFileSync(path.join(root,'codex-pets.json'),JSON.stringify({version:3,pet:pet.id,supportedPackage:'26.1002.7124.0',headerSHA256:sha(raw)},null,2));
}catch(error){fs.copyFileSync(previous,filename);fs.copyFileSync(previousExe,executable);throw error;}finally{fs.unlinkSync(temp);}
console.log('Installed pet '+pet.id+' in separate Codex copy: '+root);



require('./apply-live.cjs').applyLive(repo,root,pet.id);
