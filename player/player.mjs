import {resolveFrame} from './timeline.mjs';
export function createCanvasPlayer(canvas,pet,initial,options={}) {
 const ctx=canvas.getContext('2d'),images=new Map(options.images||[]);let props={state:'idle',reduced:false,speed:1},previousTime=performance.now(),elapsed=0,raf=0,disposed=false,ready=Boolean(options.images),last='';
 function advance(now){elapsed+=Math.max(0,now-previousTime)*props.speed;previousTime=now;}
 const files=[...new Set(Object.values(pet.actions).flatMap(a=>a.frames.map(f=>f.file)))];
 if(!ready)Promise.all(files.map(async file=>{const im=new Image();im.src=new URL('./pet/'+file,import.meta.url).href;await im.decode();if(!disposed)images.set(file,im);})).then(()=>{if(!disposed){ready=true;schedule();}}).catch(e=>{if(!disposed)options.onError?.(e);});
 function draw(now) {
  advance(now);
  const resolved=resolveFrame(pet,props.state,elapsed,props.reduced),f=resolved.frame,im=ready?images.get(f.file):initial;
  const rect=ready?(f.rect||[0,0,im.width,im.height]):(pet.actions[pet.defaultAction].frames[0].rect||[0,0,im.width,im.height]);
  const [sx,sy,sw,sh]=rect,box=canvas.getBoundingClientRect(),ratio=Math.min(devicePixelRatio||1,3),w=Math.max(1,Math.round(box.width*ratio)),h=Math.max(1,Math.round(box.height*ratio));
  const key=[resolved.action,resolved.index,resolved.mirror,w,h,ready].join(':');if(key===last)return;last=key;
  if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}ctx.clearRect(0,0,w,h);ctx.imageSmoothingEnabled=true;ctx.imageSmoothingQuality='high';const scale=Math.min(w/sw,h/sh);
  ctx.save();if(resolved.mirror){ctx.translate(w,0);ctx.scale(-1,1);}ctx.drawImage(im,sx,sy,sw,sh,(w-sw*scale)/2,h-sh*scale,sw*scale,sh*scale);ctx.restore();
  canvas.dataset.petAction=resolved.action;canvas.dataset.petFrame=String(resolved.index);canvas.dataset.ready=String(ready);
 }
 function schedule(){if(!disposed&&!document.hidden&&!raf)raf=requestAnimationFrame(tick);}
 function tick(t){raf=0;if(disposed)return;try{draw(t);}catch(e){disposed=true;options.onError?.(e);return;}if(!props.reduced)schedule();}
 function visibility(){if(document.hidden){cancelAnimationFrame(raf);raf=0;}else{last='';schedule();}}
 const resize=new ResizeObserver(()=>{last='';schedule();});resize.observe(canvas);document.addEventListener('visibilitychange',visibility);schedule();
 return {update(next){
  advance(performance.now());
  if(next.state&&next.state!==props.state){
   const previous=resolveFrame(pet,props.state,0),incoming=resolveFrame(pet,next.state,0);
   const sequenceChanged=pet.idleSequence&&(props.state==='idle'||next.state==='idle');
   if(previous.action!==incoming.action||previous.mirror!==incoming.mirror||sequenceChanged)elapsed=0;
  }
  const speed=next.speed===undefined?props.speed:next.speed;
  if(!Number.isFinite(speed)||speed<0.2||speed>5)throw Error('Animation speed must be between 0.2 and 5.');
  props={...props,...next,speed};last='';schedule();
 },dispose(){disposed=true;cancelAnimationFrame(raf);resize.disconnect();document.removeEventListener('visibilitychange',visibility);images.clear();}};
}
