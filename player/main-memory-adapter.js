// Experimental in-memory adapter. Does not replace app files or native event handlers.
(() => {
 if (window.__xlinkMainPlayer?.version===2) return;
 window.__xlinkMainPlayer?.stop();
 let controller=null,canvas=null,native=null,host=null,active=null,observer=null,revision=0;
 const style=document.createElement('style');style.id='xlink-main-player-style';
 style.textContent='[data-xlink-hidden="true"]{opacity:0!important}';
 function detach(){controller?.dispose();controller=null;canvas?.remove();canvas=null;native?.removeAttribute('data-xlink-hidden');native=null;host=null;}
 function sync(){
  if(!active)return;
  const root=document.querySelector('[data-avatar-mascot="true"] .codex-avatar-root[data-codex-pet-state]');
  if(!root){if(native&&!native.isConnected)detach();return;}
  if(root!==native){detach();native=root;host=root.parentElement;canvas=document.createElement('canvas');canvas.dataset.xlinkMainPlayer=active.pet.id;canvas.setAttribute('aria-hidden','true');canvas.style.cssText='position:absolute;inset:0;width:100%;height:100%;pointer-events:none;z-index:11';host.append(canvas);controller=createCanvasPlayer(canvas,active.pet,active.images.values().next().value,{images:active.images,onError:()=>window.__xlinkMainPlayer.stop()});native.setAttribute('data-xlink-hidden','true');}
  controller.update({state:native.dataset.codexPetState||'idle',speed:active.speed,reduced:document.documentElement.dataset.reducedMotion==='true'||(document.documentElement.dataset.reducedMotion!=='false'&&matchMedia('(prefers-reduced-motion: reduce)').matches)});
 }
 window.__xlinkMainPlayer={
  version:2,
  setSpeed(speed){if(!Number.isFinite(speed)||speed<0.2||speed>5)throw Error('Invalid animation speed');if(active&&active.speed!==speed){active.speed=speed;sync();}return this.status();},
  async apply(pet,sources,speed=1){if(!Number.isFinite(speed)||speed<0.2||speed>5)throw Error('Invalid animation speed');const ticket=++revision;const images=new Map();await Promise.all([...new Set(Object.values(pet.actions).flatMap(a=>a.frames.map(f=>f.file)))].map(async file=>{if(!sources[file]?.startsWith('data:image/png;base64,'))throw Error('Invalid PNG');const im=new Image();im.src=sources[file];await im.decode();images.set(file,im);}));if(ticket!==revision)return false;
   detach();active={pet,images,speed};if(!style.isConnected)document.head.append(style);
   if(!observer){observer=new MutationObserver(sync);observer.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['data-codex-pet-state','data-reduced-motion']});}
   sync();return Boolean(controller);
  },
  stop(){revision++;observer?.disconnect();observer=null;detach();active=null;style.remove();},
  status(){return {active:!!controller,pet:active?.pet.id,state:native?.dataset.codexPetState,speed:active?.speed};}
 };
})();
