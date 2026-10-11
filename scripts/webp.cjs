// Read animation timing without decoding image pixels.
function webpFrames(data,file) {
 if(data.length<30||data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WEBP'||data.readUInt32LE(4)+8!==data.length)throw Error('Invalid WebP: '+file);
 const frames=[];
 for(let pos=12;pos<data.length;){
  if(pos+8>data.length)throw Error('Truncated WebP chunk');
  const tag=data.toString('ascii',pos,pos+4),size=data.readUInt32LE(pos+4),end=pos+8+size;
  if(end+(size&1)>data.length)throw Error('Truncated WebP chunk');
  if(tag==='ANMF'){
   if(size<16)throw Error('Invalid WebP animation frame');
   const durationMs=data.readUIntLE(pos+20,3);
   if(durationMs<1||durationMs>60000)throw Error('Unsupported WebP frame duration');
   frames.push({file,imageFrame:frames.length,durationMs});
  }
  pos=end+(size&1);
 }
 if(!frames.length)throw Error('WebP action must contain animation frames');
 return frames;
}
module.exports={webpFrames};
