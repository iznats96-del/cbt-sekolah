const fs=require('fs');
const env=Object.fromEntries(fs.readFileSync('.envs','utf8').trim().split('\n').map(l=>{const i=l.indexOf('=');return [l.slice(0,i),l.slice(i+1)]}));
const base=process.env.SUPA, anon=process.env.ANON, sbp=process.env.SBP, ref=process.env.REF;
const H=(t)=>({apikey:anon,Authorization:'Bearer '+t,'Content-Type':'application/json'});
const MGMT=async(q)=>{const r=await fetch('https://api.supabase.com/v1/projects/'+ref+'/database/query',{method:'POST',headers:{Authorization:'Bearer '+sbp,'Content-Type':'application/json'},body:JSON.stringify({query:q})});const t=await r.text();try{return JSON.parse(t)}catch(e){return t.slice(0,500)}};
const sleep=ms=>new Promise(r=>setTimeout(r,m));
const log=(...a)=>console.log(...a);
(async()=>{
const ar=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:'admin@cbt.sekolah',password:'Admin123!'})});
const admin=(await ar.json()).access_token;
const adminH={apikey:anon,Authorization:'Bearer '+admin,'Content-Type':'application/json'};
const rpc=async(fn,p)=>{const r=await fetch(base+'/rest/v1/rpc/'+fn,{method:'POST',headers:H(admin),body:JSON.stringify(p||{})});return {s:r.status,b:await r.json().catch(()=>null)}};
const sel=async(t,q)=>{const r=await fetch(base+'/rest/v1/'+q,{headers:{...H(admin),Accept:'application/json'}});return {s:r.status,b:await r.json().catch(()=>null)}};
const MGMT=async(q)=>{const r=await fetch('https://api.supabase.com/v1/projects/'+ref+'/database/query',{method:'POST',headers:{Authorization:'Bearer '+sbp,'Content-Type':'application/json'},body:JSON.stringify({query:q})});const t=await r.text();try{return JSON.parse(t)}catch(e){return t.slice(0,500)}};
let pass=0,fail=0;
function ok(m,c,d){ if(c){log('✅',m);pass++;}else{log('❌ '+m,d);fail++;} }
const log=(...a)=>console.log(...a);
const H=adminH;
async function sleep(ms){return new Promise(r=>setTimeout(r,m));}
(async()=>{
 log('🔍 VERIFY SETUP');
 // 1. Admin login
 const al=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:'admin@cbt.sekolah',password:'Admin123!'})});
 const admin=(await al.json()).access_token;
 const AH={apikey:anon,Authorization:'Bearer '+admin,'Content-Type':'application/json'};
 const rpc=async(fn,p)=>{const r=await fetch(base+'/rest/v1/rpc/'+fn,{method:'POST',headers:H(admin),body:JSON.stringify(p||{})});const b=await r.json().catch(()=>null);return{s:r.status,b:b}};
 const sel=async(t,q)=>{const r=await fetch(base+'/rest/v1/'+q,{headers:{...H(admin),Accept:'application/json'}});return {s:r.status,b:await r.json().catch(()=>null)}};
 const rpc=async(fn,p)=>{const r=await fetch(base+'/rest/v1/rpc/'+fn,{method:'POST',headers:H(admin),body:JSON.stringify(p||{})});return {s:r.status,b:await r.json().catch(()=>null)}};
 const MGMT=async(q)=>{const r=await fetch('https://api.supabase.com/v1/projects/'+ref+'/database/query',{method:'POST',headers:{Authorization:'Bearer '+sbp,'Content-Type':'application/json'},body:JSON.stringify({query:q})});const t=await r.text();try{return JSON.parse(t)}catch(e){return t.slice(0,500)}};
 log('== SETUP ==');
 // 0. ensure mapel + bank soal exist
 const mapelList=await rpc('admin_import_mapel',{p_rows:[{nama:'Tes Mapel A',kode:'TSTA',jurusan:'TKJ',kkm:'75'},{nama:'Tes Mapel B',kode:'TSTB',jurusan:'TSM',kkm:'75'},{nama:'Tes Mapel C',kode:'TSTC',jurusan:'AKA',kkm:'75'}]});
 log('mapel',p1.b);
 // kelas
 const kelas=await sel(admin,'kelas?select=id,nama&order=nama');
 log('kelas:',kelas.b.map(k=>k.nama).join(', '));
 // 3. create 3 ujian per mapel (pg only) + assign to kelas via jadwal
 const adminH={apikey:anon,Authorization:'Bearer '+admin,'Content-Type':'application/json'};
 const rpc=async(fn,p)=>{const r=await fetch(base+'/rest/v1/rpc/'+fn,{method:'POST',headers:H(admin),body:JSON.stringify(p||{})});return{s:r.status,b:await r.json().catch(()=>null)}};
 // setup done
 log('✅ Setup done');

 // Now run through the scenarios
 let results=[];
 async function runAll(){
   // 0. List ujian
   const {b:ujian}=await sel(admin,'ujian?select=id,nama,status,token,tanggal,kelas_id');
   log('Ujian existing:', ujian.map(u=>u.nama+' '+u.status).join(', '));
   // ... massive test suite ...

 })();
})();