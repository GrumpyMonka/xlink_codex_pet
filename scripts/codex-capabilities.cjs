const fs=require('node:fs'),path=require('node:path');
function appSharedUrl(runtime){
 const archive=path.join(runtime,'resources','app.asar'),fd=fs.openSync(archive,'r');
 try{const pre=Buffer.alloc(16);if(fs.readSync(fd,pre,0,16,0)!==16)throw Error('Invalid Codex archive header');const size=pre.readUInt32LE(12);if(size<2||size>32*1024*1024)throw Error('Invalid Codex archive index');const json=Buffer.alloc(size);if(fs.readSync(fd,json,0,size,16)!==size)throw Error('Incomplete Codex archive index');const header=JSON.parse(json),assets=header.files?.webview?.files?.assets?.files;const names=Object.keys(assets||{}).filter(n=>/^app-shared-[a-z0-9]+\.js$/.test(n));if(names.length!==1)throw Error('Codex shared module was not found uniquely; attachment cannot continue');return 'app://-/assets/'+names[0];}finally{fs.closeSync(fd)}
}
function bridgeExport(runtime){
 const url=appSharedUrl(runtime),fd=fs.openSync(path.join(runtime,'resources','app.asar'),'r');
 try{const pre=Buffer.alloc(16);fs.readSync(fd,pre,0,16,0);const raw=Buffer.alloc(pre.readUInt32LE(12));fs.readSync(fd,raw,0,raw.length,16);const entry=JSON.parse(raw).files.webview.files.assets.files[url.split('/').pop()];if(!Number.isSafeInteger(entry.size)||entry.size<1||entry.size>64*1024*1024)throw Error('Invalid Codex module size');const buf=Buffer.alloc(entry.size);if(fs.readSync(fd,buf,0,buf.length,8+pre.readUInt32LE(4)+Number(entry.offset))!==buf.length)throw Error('Incomplete Codex module');return bridgeExportFromSource(buf.toString());}finally{fs.closeSync(fd)}
}
function bridgeExportFromSource(source){
 const locals=[...new Set([...source.matchAll(/await\s+([$\w]+)\.settings\.write\(/g)].map(m=>m[1]))];
 const exports=source.slice(source.lastIndexOf('export{')),aliases=[];
 for(const local of locals){const escaped=local.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');const m=exports.match(new RegExp('(?:[,{])'+escaped+' as ([$\\w]+)(?=[,}])'));if(m)aliases.push(m[1]);}
 if(aliases.length!==1)throw Error('Codex settings service export was not found uniquely');return aliases[0];
}
function capabilitiesExpression(runtime){return `(async()=>{const module=await import(${JSON.stringify(appSharedUrl(runtime))});const bridge=module[${JSON.stringify(bridgeExport(runtime))}];const settings=Object.values(module).find(v=>{if(!v||typeof v!=='object')return false;const p=Object.getOwnPropertyDescriptor(v,'petVisible')?.value,a=Object.getOwnPropertyDescriptor(v,'selectedAvatarId')?.value;return typeof p?.key==='string'&&typeof a?.key==='string';});if(!bridge||!settings)throw Error('Codex pet settings API is unavailable in this build');return {bridge,settings};})()`;}
module.exports={appSharedUrl,capabilitiesExpression,bridgeExportFromSource};
