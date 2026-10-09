const fs = require('node:fs');
const path = require('node:path');
const ID = /^[a-z0-9][a-z0-9-]{0,63}$/;
function assetPath(root, file) {
  if (typeof file !== 'string' || !/^[a-zA-Z0-9_./-]+\.png$/.test(file) || file.startsWith('/') || file.split('/').some(p => p === '..' || !p)) throw Error('Invalid asset path: ' + file);
  const target = path.resolve(root, file), relative = path.relative(root, target);
  if (relative.startsWith('..') || path.isAbsolute(relative)) throw Error('Asset outside pet directory');
  const real = fs.realpathSync(target), realRelative = path.relative(fs.realpathSync(root), real);
  if (realRelative.startsWith('..') || path.isAbsolute(realRelative)) throw Error('Asset symlink outside pet directory');
  return target;
}
function readPet(repo, id) {
  if (!ID.test(id)) throw Error('Invalid pet id');
  return readPetDirectory(path.join(repo,'pets',id),id);
}
function readPetDirectory(root,id) {
  if (!ID.test(id)) throw Error('Invalid pet id');
  const pet = JSON.parse(fs.readFileSync(path.join(root, 'pet.json'), 'utf8').replace(/^\uFEFF/, ''));
  if (pet.formatVersion !== 1 || pet.id !== id || typeof pet.name !== 'string' || !pet.actions?.[pet.defaultAction]) throw Error('Invalid pet metadata: ' + id);
  const licenseKeys=Object.keys(pet.license||{});
  if(licenseKeys.length!==1||!['url','text'].includes(licenseKeys[0])||typeof pet.license[licenseKeys[0]]!=='string'||!pet.license[licenseKeys[0]].trim())throw Error('License must contain exactly one non-empty url or text');
  function validateUrl(value,label){if(value===undefined)return;let url;try{url=new URL(value);}catch{throw Error('Invalid '+label+' URL');}if(typeof value!=='string'||url.protocol!=='https:'||url.username||url.password)throw Error('Invalid '+label+' URL');}
  if(pet.author!==undefined){if(!pet.author||typeof pet.author.name!=='string'||!pet.author.name.trim())throw Error('Invalid author');validateUrl(pet.author.url,'author');}
  validateUrl(pet.license.url,'license');
  const assets = new Map();
  for (const [name, action] of Object.entries(pet.actions)) {
    if (!ID.test(name) || !Array.isArray(action.frames) || !action.frames.length) throw Error('Invalid action: ' + name);
    for (const frame of action.frames) {
      if (!Number.isFinite(frame.durationMs) || frame.durationMs < 1 || frame.durationMs > 60000) throw Error('Invalid frame duration: ' + name);
      if (!assets.has(frame.file)) {
        const file = assetPath(root, frame.file), data = fs.readFileSync(file);
        if (!data.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) || data.length < 24) throw Error('Not a PNG: ' + frame.file);
        assets.set(frame.file, {file, width: data.readUInt32BE(16), height: data.readUInt32BE(20)});
      }
      const image = assets.get(frame.file);
      if (frame.rect) {
        const [x,y,w,h] = frame.rect;
        if (frame.rect.length !== 4 || !frame.rect.every(Number.isInteger) || x < 0 || y < 0 || w < 1 || h < 1 || x+w > image.width || y+h > image.height) throw Error('Frame outside PNG: ' + name);
      }
    }
  }
  for (const [state, binding] of Object.entries(pet.bindings || {})) {
    if (!pet.actions[binding.action] || (binding.mirror !== undefined && typeof binding.mirror !== 'boolean')) throw Error('Invalid binding: ' + state);
  }
  if (pet.idleSequence && (!Array.isArray(pet.idleSequence) || !pet.idleSequence.length || pet.idleSequence.some(a => !pet.actions[a]))) throw Error('Invalid idle sequence');
  return {pet, assets, root};
}
module.exports = {readPet, readPetDirectory, assetPath};
