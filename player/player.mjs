import {resolveFrame,transitionElapsed} from './timeline.mjs';
export async function loadPetImage(src,file) {
 if(!file.endsWith('.webp')){const im=new Image();im.src=src;await im.decode();return im;}
 if(typeof ImageDecoder==='undefined'||!await ImageDecoder.isTypeSupported('image/webp'))throw Error('Animated WebP decoding is unavailable');
 const data=src.startsWith('data:')?Uint8Array.from(atob(src.slice(src.indexOf(',')+1)),c=>c.charCodeAt(0)) : await (await fetch(src)).arrayBuffer();
 const decoder=new ImageDecoder({data,type:'image/webp',preferAnimation:true});
 try{await decoder.tracks.ready;const first=(await decoder.decode({frameIndex:0})).image;return {decoder,first,width:first.displayWidth,height:first.displayHeight};}catch(e){decoder.close();throw e;}
}
export function releasePetImages(images){for(const im of images.values()){im.first?.close();im.decoder?.close();}images.clear();}
export function createCanvasPlayer(canvas,pet,initial,options={}) {
 const ctx=canvas.getContext('2d'),images=new Map(options.images||[]);let props={state:'idle',reduced:false,speed:1},previousTime=performance.now(),elapsed=0,raf=0,disposed=false,ready=Boolean(options.images),last='';
 let decoded=null,decodedFile='',decodedIndex=-1,busy=false,wanted=null;
 async function decodeWanted(){
  if(busy||disposed||!wanted)return;const target=wanted;
  if(decodedFile===target.file&&decodedIndex===target.index)return;
  busy=true;
  try{const result=await images.get(target.file).decoder.decode({frameIndex:target.index});
   if(disposed){result.image.close();return;}
   decoded?.close();decoded=result.image;decodedFile=target.file;decodedIndex=target.index;last='';schedule();
  }catch(e){if(!disposed){disposed=true;options.onError?.(e);}}
  finally{busy=false;if(!disposed&&wanted&&(wanted.file!==target.file||wanted.index!==target.index))decodeWanted();}
 }
 function advance(now){elapsed+=Math.max(0,now-previousTime)*props.speed;previousTime=now;}
 const files=[...new Set(Object.values(pet.actions).flatMap(a=>a.frames.map(f=>f.file)))];
 if(!ready)Promise.all(files.map(async file=>{const im=await loadPetImage(new URL('./pet/'+file,import.meta.url).href,file);if(!disposed)images.set(file,im);else{im.first?.close();im.decoder?.close();}})).then(()=>{if(!disposed){ready=true;schedule();}}).catch(e=>{if(!disposed)options.onError?.(e);});
 function draw(now) {
  advance(now);
  const resolved=resolveFrame(pet,props.state,elapsed,props.reduced),f=resolved.frame,im=ready?images.get(f.file):initial;
  let drawable=im;
  if(im.decoder){const index=f.imageFrame||0;wanted={file:f.file,index};decodeWanted();drawable=decodedFile===f.file?decoded:im.first;}
  else wanted=null;
  const rect=ready?(f.rect||[0,0,im.width,im.height]):(pet.actions[pet.defaultAction].frames[0].rect||[0,0,im.width,im.height]);
  const [sx,sy,sw,sh]=rect,box=canvas.getBoundingClientRect(),ratio=Math.min(devicePixelRatio||1,3),w=Math.max(1,Math.round(box.width*ratio)),h=Math.max(1,Math.round(box.height*ratio));
  const key=[resolved.action,im.decoder?decodedIndex:resolved.index,resolved.mirror,w,h,ready].join(':');if(key===last)return;last=key;
  if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}ctx.clearRect(0,0,w,h);ctx.imageSmoothingEnabled=true;ctx.imageSmoothingQuality='high';const scale=Math.min(w/sw,h/sh);
  ctx.save();if(resolved.mirror){ctx.translate(w,0);ctx.scale(-1,1);}ctx.drawImage(drawable,sx,sy,sw,sh,(w-sw*scale)/2,h-sh*scale,sw*scale,sh*scale);ctx.restore();
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
   if(previous.action!==incoming.action||previous.mirror!==incoming.mirror||sequenceChanged)elapsed=sequenceChanged||previous.mirror!==incoming.mirror?0:transitionElapsed(pet.actions[previous.action],pet.actions[incoming.action],elapsed);
  }
  const speed=next.speed===undefined?props.speed:next.speed;
  if(!Number.isFinite(speed)||speed<0.2||speed>5)throw Error('Animation speed must be between 0.2 and 5.');
  props={...props,...next,speed};last='';schedule();
 },dispose(){disposed=true;cancelAnimationFrame(raf);resize.disconnect();document.removeEventListener('visibilitychange',visibility);decoded?.close();decoded=null;if(!options.images)releasePetImages(images);}};
}
