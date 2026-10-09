const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const {verifyMain}=require('./main-session.cjs');
const {readSpeeds}=require('./playback.cjs');
const repo=path.resolve(__dirname,'..'),state=path.join(repo,'.runtime'),port=9340;
const script=fs.readFileSync(path.join(repo,'player/main-toolbar.js'),'utf8').replace('XLINK_LOGO',JSON.stringify('data:image/svg+xml;base64,'+fs.readFileSync(path.join(repo,'player/assets/xlink.svg')).toString('base64')));
let scriptId=null,lastOpen=0,connection=null,sequence=0,pending=new Map();
let lastPlayback='',updatingPlayback=false;
const playbackTimer=setInterval(async()=>{
 if(updatingPlayback||!connection||connection.readyState!==WebSocket.OPEN||!enabled())return;
 const speeds=JSON.stringify(readSpeeds(repo));if(speeds===lastPlayback)return;
 updatingPlayback=true;
 try{await send('Runtime.evaluate',{expression:'(()=>{const p=window.__xlinkMainPlayer;if(p?.setSpeed){const speeds='+speeds+';p.setSpeed(speeds[p.status().pet]??1);}})()'});lastPlayback=speeds;}catch{lastPlayback='';}finally{updatingPlayback=false;}
},300);
function enabled(){try{return JSON.parse(fs.readFileSync(path.join(state,'main-settings.json'),'utf8').replace(/^\uFEFF/,'')).enabled;}catch{return false;}}
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++sequence,timer=setTimeout(()=>{pending.delete(id);reject(Error('Toolbar connection timed out'));},5000);pending.set(id,{resolve,reject,timer});connection.send(JSON.stringify({id,method,params}));});}
function disconnect(){connection?.close();connection=null;lastPlayback='';for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('Toolbar disconnected'));}pending.clear();}
async function attach(){
 verifyMain(port);
 const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`,{signal:AbortSignal.timeout(2000)})).json();
 const target=targets.find(t=>t.type==='page'&&t.url.startsWith('app://-/index.html')&&t.url.includes('avatar-overlay'));if(!target)return;
 const url=new URL(target.webSocketDebuggerUrl);if(url.hostname!=='127.0.0.1'||Number(url.port)!==port||url.protocol!=='ws:')throw Error('Unexpected endpoint');
 const ws=connection=new WebSocket(url);
 ws.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.id){const p=pending.get(message.id);if(p){clearTimeout(p.timer);pending.delete(message.id);message.error?p.reject(Error(message.error.message)):p.resolve(message.result);}return;}
  if(message.method==='Runtime.bindingCalled')console.log('binding',message.params.name,message.params.payload);
  if(message.method==='Runtime.bindingCalled'&&message.params.name==='xlinkOpenManager'&&message.params.payload==='open'&&enabled()&&Date.now()-lastOpen>1200){lastOpen=Date.now();const log=fs.openSync(path.join(state,'manager-launch.log'),'a');const child=cp.spawn('powershell.exe',['-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'Manager.ps1')],{windowsHide:true,stdio:['ignore',log,log],detached:false});fs.closeSync(log);console.log('manager launch',child.pid);child.on('exit',(code)=>console.log('manager exit',code));child.on('error',e=>console.error(e.message));child.unref();}
 });
 await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Toolbar connect timeout')),5000);ws.addEventListener('open',()=>{clearTimeout(timer);resolve();},{once:true});ws.addEventListener('error',()=>{clearTimeout(timer);reject(Error('Toolbar connection failed'));},{once:true});});
 ws.addEventListener('close',()=>{if(connection===ws)disconnect();});ws.addEventListener('error',()=>{});
 await send('Runtime.enable');await send('Runtime.evaluate',{expression:'delete window.xlinkOpenManager;delete window.__xlinkBridgeSeen'});await send('Runtime.addBinding',{name:'xlinkOpenManager'});
 scriptId=(await send('Page.addScriptToEvaluateOnNewDocument',{source:script})).identifier;await send('Runtime.evaluate',{expression:script+";window.__xlinkBridgeSeen=Date.now()"});
}
let maintaining=false,lastMaintenance=0,lastMessage='';
let trayProcess=null,lastTrayStart=0;
function ensureTray(){
 if(trayProcess||Date.now()-lastTrayStart<10000||!enabled())return;
 lastTrayStart=Date.now();
 const log=fs.openSync(path.join(state,'tray.log'),'a');
 trayProcess=cp.spawn('powershell.exe',['-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'Tray.ps1'),'-OwnerId',String(process.pid)],{windowsHide:true,stdio:['ignore',log,log]});
 fs.closeSync(log);
 trayProcess.on('error',e=>{report('Tray: '+e.message);trayProcess=null});
 trayProcess.on('exit',()=>{trayProcess=null});
 // The tray watches our PID and exits after bridge shutdown, not vice versa.
 trayProcess.unref();
}
function report(message){if(message===lastMessage)return;lastMessage=message;fs.appendFileSync(path.join(state,'main-watch.log'),new Date().toISOString()+' '+message+'\n');}
function maintain(){
 if(maintaining||Date.now()-lastMaintenance<3000||!enabled())return;
 maintaining=true;lastMaintenance=Date.now();
 const child=cp.spawn('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'Main.ps1'),'-Action','watch'],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let output='';child.stdout.on('data',b=>{output=(output+b).slice(-8000)});child.stderr.on('data',b=>{output=(output+b).slice(-8000)});
 child.on('error',e=>{maintaining=false;report(e.message)});
 child.on('close',code=>{maintaining=false;report(code===0?'Connected or waiting for Codex.':output.trim()||'Attachment failed.');});
}
(async()=>{while(enabled()){
 ensureTray();
 maintain();
 try{if(!connection)await attach();else await send('Runtime.evaluate',{expression:script+";window.__xlinkBridgeSeen=Date.now()"});}catch(e){disconnect();}
 await new Promise(resolve=>setTimeout(resolve,1500));
 }clearInterval(playbackTimer);if(connection){try{if(scriptId)await send('Page.removeScriptToEvaluateOnNewDocument',{identifier:scriptId});await send('Runtime.evaluate',{expression:'window.__xlinkToolbar?.stop();delete window.xlinkOpenManager'});await send('Runtime.removeBinding',{name:'xlinkOpenManager'});}catch{}}disconnect();})().catch(e=>{clearInterval(playbackTimer);console.error(e.message);disconnect();process.exitCode=1;});
