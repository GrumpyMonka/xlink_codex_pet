const test=require('node:test'),assert=require('node:assert/strict');
const {webpFrames}=require('../scripts/webp.cjs');
function sample(durations){const body=Buffer.alloc(4+durations.length*24);body.write('WEBP');durations.forEach((n,i)=>{const p=4+i*24;body.write('ANMF',p);body.writeUInt32LE(16,p+4);body.writeUIntLE(n,p+20,3)});const h=Buffer.alloc(8);h.write('RIFF');h.writeUInt32LE(body.length,4);return Buffer.concat([h,body]);}
test('embedded nonuniform WebP timing and malformed chunks',()=>{
 assert.deepEqual(webpFrames(sample([42,83,125]),'a.webp').map(f=>f.durationMs),[42,83,125]);
 assert.throws(()=>webpFrames(sample([0]),'a.webp'));
 const broken=sample([42]);broken.writeUInt32LE(1000,16);assert.throws(()=>webpFrames(broken,'a.webp'));
 assert.throws(()=>webpFrames(sample([42]).subarray(0,31),'a.webp'));
});
