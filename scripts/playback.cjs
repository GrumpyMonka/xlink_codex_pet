const fs=require('node:fs'),path=require('node:path');
function readSpeeds(repo){
 try{const settings=JSON.parse(fs.readFileSync(path.join(repo,'.runtime/playback-settings.json'),'utf8').replace(/^\uFEFF/,''));
  return Object.fromEntries(Object.entries(settings.speeds||{}).filter(([id,speed])=>/^[a-z0-9][a-z0-9-]{0,63}$/.test(id)&&Number.isFinite(speed)&&speed>=0.2&&speed<=5));
 }catch{return {};}
}
module.exports={readSpeeds};
