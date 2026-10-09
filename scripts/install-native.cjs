const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');const {readPet,assetPath}=require('./pets.cjs');
function nativeSupport(repo,id){try{const {pet}=readPet(repo,id);const n=pet.native;if(!n)return{supported:false,reason:'Нативный спрайт-лист не подготовлен'};if(![1,2].includes(n.spriteVersionNumber))throw Error('Invalid native version');const file=assetPath(path.join(repo,'pets',id),n.spritesheet),data=fs.readFileSync(file);if(data.length>20*1024*1024||data.readUInt32BE(16)!==1536||data.readUInt32BE(20)!==(n.spriteVersionNumber===2?2288:1872))throw Error('Invalid native atlas dimensions/size');return{supported:true,version:n.spriteVersionNumber,file};}catch(e){return{supported:false,reason:e.message};}}
function installNative(repo){const settings=JSON.parse(fs.readFileSync(path.join(repo,'.runtime/settings.json'),'utf8').replace(/^\uFEFF/,''));const runtime=path.resolve(settings.runtime);if(/windowsapps/i.test(runtime)||!['.codex-pets-runtime','.yuki-player-lab'].some(m=>fs.existsSync(path.join(runtime,m))))throw Error('Expected managed runtime');return settings;}
function install(repo,id,main=false){const support=nativeSupport(repo,id);if(!support.supported)throw Error(support.reason);const {pet}=readPet(repo,id),settings=main?null:installNative(repo);const root=main?path.join(require('os').homedir(),'.codex','pets'):path.resolve(settings.profile,'codex-home','pets');fs.mkdirSync(root,{recursive:true});const key='xlink-manager-'+id,dest=path.join(root,key),tag=path.join(dest,'.xlink-manager.json');const data=fs.readFileSync(support.file),hash=crypto.createHash('sha256').update(data).digest('hex');
 if(fs.existsSync(dest)){
  if(!fs.existsSync(tag))throw Error('Existing native pet is not managed by this installer');
  const old=JSON.parse(fs.readFileSync(tag));if(old.id!==id)throw Error('Managed pet ID differs');
  const manifestPath=path.join(dest,'pet.json'),manifest=JSON.parse(fs.readFileSync(manifestPath));
  if(!/^spritesheet(?:-[a-f0-9]{16})?\.png$/.test(manifest.spritesheetPath))throw Error('Unexpected installed asset path');
  const existing=fs.readFileSync(path.join(dest,manifest.spritesheetPath));
  if(crypto.createHash('sha256').update(existing).digest('hex')!==old.sha256)throw Error('Installed pet was modified outside this installer');
  if(old.sha256===hash)return{id:'custom:'+key,path:dest,reused:true};
  const backup=path.join(repo,'.runtime','native-backups',key+'-'+crypto.randomUUID());fs.mkdirSync(path.dirname(backup),{recursive:true});fs.cpSync(dest,backup,{recursive:true});
  const assetName='spritesheet-'+hash.slice(0,16)+'.png';fs.writeFileSync(path.join(dest,assetName),data);
  const updated={displayName:pet.name,description:pet.description,spriteVersionNumber:support.version,spritesheetPath:assetName};
  fs.writeFileSync(manifestPath+'.tmp',JSON.stringify(updated,null,2));fs.renameSync(manifestPath+'.tmp',manifestPath);
  fs.writeFileSync(tag,JSON.stringify({id,sha256:hash}));return{id:'custom:'+key,path:dest,updated:true,backup};
 }
 const temp=path.join(root,'.install-'+crypto.randomUUID());fs.mkdirSync(temp);fs.writeFileSync(path.join(temp,'spritesheet.png'),data);fs.writeFileSync(path.join(temp,'pet.json'),JSON.stringify({displayName:pet.name,description:pet.description,spriteVersionNumber:support.version,spritesheetPath:'spritesheet.png'},null,2));fs.writeFileSync(path.join(temp,'.xlink-manager.json'),JSON.stringify({id,sha256:hash}));fs.renameSync(temp,dest);return{id:'custom:'+key,path:dest,reused:false};}
if(require.main===module){try{const repo=path.resolve(__dirname,'..');if(process.argv[2]==='--capabilities'){const output={};for(const id of fs.readdirSync(path.join(repo,'pets'))){if(fs.existsSync(path.join(repo,'pets',id,'pet.json')))output[id]=nativeSupport(repo,id);}console.log(JSON.stringify(output));}else console.log(JSON.stringify(install(repo,process.argv[2],process.argv.includes('--main'))));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={nativeSupport,install};
