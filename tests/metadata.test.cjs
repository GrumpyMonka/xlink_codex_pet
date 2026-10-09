const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {readPetDirectory}=require('../scripts/pets.cjs');
test('author and license links accept HTTPS README links and reject executable schemes',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'xlink-metadata-'));
 try{
  fs.copyFileSync(path.join(__dirname,'../pets/vpet/assets/idle/000.png'),path.join(root,'frame.png'));
  const pet={formatVersion:1,id:'test',name:'test',license:{text:'test'},defaultAction:'idle',actions:{idle:{frames:[{file:'frame.png',durationMs:125}]}}};
  const read=()=>{fs.writeFileSync(path.join(root,'pet.json'),JSON.stringify(pet));return readPetDirectory(root,'test');};
  assert.doesNotThrow(read);
  pet.author={name:'Author',url:'https://github.com/example'};pet.license={url:'https://github.com/example/pet/blob/main/README.md#license'};assert.doesNotThrow(read);
  pet.license.text='extra';assert.throws(read,/exactly one/);delete pet.license.text;
  const valid=pet.license;for(const invalid of [{},{text:''},{notice:'legacy'},{url:'https://example.com',source:'extra'}]){pet.license=invalid;assert.throws(read,/exactly one/);}pet.license=valid;
  for(const bad of ['javascript:alert(1)','file:///C:/test.cmd','not a URL','https://user:pass@example.com']){pet.license.url=bad;assert.throws(read,/license URL/);}
  pet.license={text:'test'};pet.author.url='file:///C:/test.cmd';assert.throws(read,/author URL/);
 }finally{assert.equal(path.dirname(root),path.resolve(os.tmpdir()));assert(path.basename(root).startsWith('xlink-metadata-'));fs.rmSync(root,{recursive:true,force:true});}
});
