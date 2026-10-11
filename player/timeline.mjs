export function duration(action) { return action.frames.reduce((n,f)=>n+f.durationMs,0); }
// Related clips may differ only in holds; preserve the pose and travel direction.
export function transitionElapsed(previous,incoming,elapsed) {
 if(!previous.continuityGroup||previous.continuityGroup!==incoming.continuityGroup||previous.frames.length!==incoming.frames.length||previous.frames.some((f,i)=>f.file!==incoming.frames[i].file))return 0;
 let time=Math.max(0,elapsed)%duration(previous),index=0;
 while(index<previous.frames.length-1&&time>=previous.frames[index].durationMs){time-=previous.frames[index].durationMs;index++;}
 return incoming.frames.slice(0,index).reduce((n,f)=>n+f.durationMs,0)+time/previous.frames[index].durationMs*incoming.frames[index].durationMs;
}
export function resolveFrame(pet,state,elapsed,reduced=false) {
 const binding=pet.bindings?.[state]||{action:pet.defaultAction};let action=binding.action,time=reduced?0:Math.max(0,elapsed);
 if(state==='idle'&&pet.idleSequence&&!reduced){const total=pet.idleSequence.reduce((n,a)=>n+duration(pet.actions[a]),0);time%=total;for(const a of pet.idleSequence){action=a;const d=duration(pet.actions[a]);if(time<d)break;time-=d;}}
 const clip=pet.actions[action];time%=duration(clip);let index=0;while(index<clip.frames.length-1&&time>=clip.frames[index].durationMs){time-=clip.frames[index].durationMs;index++;}
 return {action,index,frame:clip.frames[index],mirror:!!binding.mirror};
}
