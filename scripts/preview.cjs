const fs=require('node:fs'),path=require('node:path'),http=require('node:http');const {readPet}=require('./pets.cjs');
function createPreview(repo,id){const {pet,assets}=readPet(repo,id),routes=new Map();
 routes.set('/',{type:'text/html; charset=utf-8',data:fs.readFileSync(path.join(repo,'player/preview.html'))});
 for(const name of ['player.mjs','timeline.mjs'])routes.set('/player/'+name,{type:'text/javascript',data:fs.readFileSync(path.join(repo,'player',name))});
 routes.set('/player/manifest.mjs',{type:'text/javascript',data:Buffer.from('export const manifest='+JSON.stringify(pet)+';export const imageUrl='+JSON.stringify('/player/pet/'+pet.actions[pet.defaultAction].frames[0].file)+';')});
 for(const [name,asset]of assets)routes.set('/player/pet/'+name,{type:'image/png',file:asset.file});
 return http.createServer((req,res)=>{let key;try{key=decodeURIComponent(new URL(req.url,'http://localhost').pathname);}catch{res.writeHead(400).end();return;}const route=routes.get(key);if(!route){res.writeHead(404).end();return;}res.setHeader('Content-Type',route.type);res.setHeader('X-Content-Type-Options','nosniff');res.end(route.data||fs.readFileSync(route.file));});
}
if(require.main===module){try{const id=process.argv[2]||'vpet',port=Number(process.env.PORT||4173),server=createPreview(path.resolve(__dirname,'..'),id);server.on('error',e=>{console.error(e.message);process.exitCode=1;});server.listen(port,'127.0.0.1',()=>console.log(`Preview ${id}: http://127.0.0.1:${server.address().port}`));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={createPreview};
