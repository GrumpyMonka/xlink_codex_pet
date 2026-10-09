const fs=require('node:fs'),path=require('node:path');const {readPet}=require('./pets.cjs');
const repo=path.resolve(__dirname,'..');
try {const ids=process.argv.slice(2);for(const id of ids.length?ids:fs.readdirSync(path.join(repo,'pets'))){const {pet,assets}=readPet(repo,id);console.log(`${id}: ${Object.keys(pet.actions).length} actions, ${assets.size} PNG assets — OK`);}}catch(e){console.error(e.message);process.exitCode=1;}
