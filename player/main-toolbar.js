// One extra slot inside the native compact pill; native hover owns visibility.
(logo => {
 if(window.__xlinkToolbar?.version===8)return;window.__xlinkToolbar?.stop();
 const marked=new Set(),style=document.createElement('style');
 style.textContent=`
 form[data-xlink-compact-form] {left:calc(var(--quick-chat-composer-left) * 1px - 20px)!important;width:calc(var(--quick-chat-composer-width) * 1px + 40px)!important}
 [data-xlink-compact-voice] {left:calc(var(--quick-chat-voice-left) * 1px + 20px)!important}
 [data-xlink-compact-badge] {left:calc(var(--quick-chat-badge-left) * 1px + 20px)!important}
 form[data-xlink-compact-form] [data-quick-chat-divider="badge"] {translate:40px 0}
 #xlink-settings-button {position:absolute;left:44px;top:calc(50% - 16px);width:32px;height:32px;padding:6px;border-radius:50%;border:0;background:transparent;cursor:pointer;pointer-events:auto;z-index:2}
 #xlink-settings-button[hidden] {display:none!important}
 #xlink-settings-button:hover {background:rgba(127,127,127,.12)}
 #xlink-settings-button:focus-visible {outline:2px solid currentColor;outline-offset:-3px;border-radius:20px}
 `;document.head.append(style);
 const button=document.createElement('button');button.type='button';button.id='xlink-settings-button';
 button.setAttribute('aria-label','Открыть настройки XLink Codex Pets');button.title='Настройки XLink Codex Pets';
 button.dataset.avatarOverlayHitRegion='xlink-settings';button.dataset.avatarOverlayForeground='true';
 button.className='flex shrink-0 cursor-interaction items-center justify-center text-default';
 const img=document.createElement('img');img.src=logo;img.alt='';img.width=20;img.height=20;img.draggable=false;button.append(img);
 button.addEventListener('pointerdown',e=>e.stopPropagation());
 button.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();if(typeof window.xlinkOpenManager==='function')window.xlinkOpenManager('open');});
 function clear(){for(const e of marked){e.removeAttribute('data-xlink-compact-form');e.removeAttribute('data-xlink-compact-voice');e.removeAttribute('data-xlink-compact-badge');}marked.clear();}
 const menuItems=new Map();
 const openManager=()=>{if(typeof window.xlinkOpenManager==='function')window.xlinkOpenManager('open');};
 function patchPetSettings(){
  const mascot=document.querySelector('[data-avatar-mascot="true"]');
  if(!mascot)return;
  const key=Object.keys(mascot).find(k=>k.startsWith('__reactFiber'));
  let fiber=mascot[key];
  for(let depth=0;fiber&&depth<50;depth++,fiber=fiber.return){
   for(const props of [fiber.memoizedProps,fiber.pendingProps]){
    for(const field of ['items','avatarMenuItems']){
     const items=props?.[field];if(!Array.isArray(items))continue;
     for(const item of items){
      if(item?.id!=='pet-settings'||typeof item.onSelect!=='function'||Object.isFrozen(item))continue;
      if(item.onSelect===openManager)continue;
      menuItems.set(item,item.onSelect);item.onSelect=openManager;
     }
    }
   }
  }
 }
 // Capture runs before React/native-menu code reads the item's action.
 document.addEventListener('contextmenu',patchPetSettings,true);
 document.addEventListener('keydown',patchPetSettings,true);
 function sync(){
  patchPetSettings();
  const anchor=document.querySelector('[data-avatar-overlay-material-variant="quick-chat"] button[data-quick-chat-control]:not([data-quick-chat-return-to-voice])');
  const bar=anchor?.closest('[data-quick-chat-presentation]'),form=anchor?.closest('form');
  const surface=anchor?.closest('[data-avatar-overlay-material-variant="quick-chat"]');
  const voice=bar?.querySelector('[data-avatar-overlay-material-variant="quick-chat-voice"]')?.parentElement;
  const badge=bar?.querySelector('[data-avatar-overlay-material-variant="quick-chat-orb"][data-avatar-overlay-hit-region="mascot-badge"]')?.parentElement;
  if(!surface||!form||!voice){clear();button.remove();return;}
  const compact=surface.dataset.avatarOverlayQuickChatCollapsed==='true';
  if(!compact){if(marked.size)clear();if(!button.hidden)button.hidden=true;return;}
  clear();form.setAttribute('data-xlink-compact-form','');voice.setAttribute('data-xlink-compact-voice','');marked.add(form);marked.add(voice);
  if(badge){badge.setAttribute('data-xlink-compact-badge','');marked.add(badge);}
  if(button.parentElement!==surface)surface.append(button);
  if(button.hidden)button.hidden=false;
 }
 const observer=new MutationObserver(sync);observer.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['data-avatar-overlay-quick-chat-collapsed']});sync();
 window.__xlinkToolbar={version:8,stop(){observer.disconnect();document.removeEventListener('contextmenu',patchPetSettings,true);document.removeEventListener('keydown',patchPetSettings,true);for(const [item,original]of menuItems){if(item.onSelect===openManager)item.onSelect=original;}menuItems.clear();clear();button.remove();style.remove();delete window.__xlinkToolbar;}};
})(XLINK_LOGO);
