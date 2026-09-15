/* eslint-disable */
// BOT WARS — 384 siswa sungguhan, 12 rombel, skenario jadwal + probe keamanan
const fs=require('fs');
const env=Object.fromEntries(fs.readFileSync((process.env.HOME||'/root')+'/.cache/opencode/tmp/.envs','utf8').trim().split('\n').map(l=>[l.slice(0,l.indexOf('=')),l.slice(l.indexOf('=')+1)]));
const base=env.SUPA, anon=env.ANON, svc=env.SVC, sbp=env.SBP, ref=env.REF;
const H=(t)=>({apikey:anon,Authorization:'Bearer '+t,'Content-Type':'application/json'});
const MGMT=async(q)=>{const r=await fetch('https://api.supabase.com/v1/projects/'+ref+'/database/query',{method:'POST',headers:{Authorization:'Bearer '+sbp,'Content-Type':'application/json'},body:JSON.stringify({query:q})});const t=await r.text();if(r.status>=400){console.log('MGMT-ERR',r.status,t.slice(0,200));return [];}try{return JSON.parse(t);}catch(e){return [];}};
const rpc=async(t,fn,p)=>{const r=await fetch(base+'/rest/v1/rpc/'+fn,{method:'POST',headers:H(t),body:JSON.stringify(p||{})});let b=null;try{b=await r.json();}catch(e){}return{s:r.status,b};};
const sel=async(t,q)=>{const r=await fetch(base+'/rest/v1/'+q,{headers:{...H(t),Accept:'application/json'}});return{s:r.status,b:await r.json().catch(()=>null)};};
const ins=async(t,tab,row,fields)=>{const r=await fetch(base+'/rest/v1/'+tab+'?select='+(fields||'id'),{method:'POST',headers:{...H(t),Prefer:'return=representation'},body:JSON.stringify(row)});return{s:r.status,b:await r.json().catch(()=>null)};};
const ok=[],bad=[];
function T(n,c,d){(c?ok:bad).push(n);console.log((c?'✅ ':'❌ ')+n+(c?'':'   → '+String(JSON.stringify(d??null)).slice(0,170)));}
const sleep=(m)=>new Promise(r=>setTimeout(r,m));

(async()=>{
 console.log('== BOT WARS START ==');
 // ---- self-clean
 await MGMT("delete from public.jawaban_siswa; delete from public.hasil_ujian; delete from public.peserta_ujian; delete from public.ujian where nama like 'BOT %'; delete from public.jadwal_mapel; delete from public.bank_soal where mapel_id in (select id from public.mata_pelajaran where nama in ('Administrasi Sistem Jaringan','Sistem Fuel Injection','Akuntansi Perusahaan Jasa'));");
 const ar=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:'admin@cbt.sekolah',password:'Admin123!'})});
 const admin=(await ar.json()).access_token;

 const nowW=new Date(Date.now()+7*3600000);
 const tgl=nowW.toISOString().slice(0,10);
 const besok=new Date(nowW.getTime()+864e5).toISOString().slice(0,10);
 const hari=(nowW.getUTCDay()+6)%7+1;
 const hm=(m)=>{const x=new Date(nowW.getTime()+m*60000);return [((x.getUTCHours())%24),x.getUTCMinutes()].map(v=>String(v).padStart(2,'0')).join(':');};

 // ---- PETA KELAS: 8 buka, 2 telat(jam), 2 salah-hari(tanggal besok)
 const kelasAll=(await sel(admin,'kelas?select=id,nama&order=nama')).b;
 const kodeMap={}; kelasAll.forEach(k=>kodeMap[k.nama]=k.id);
 const scOf=(i)=> i<8?'open':(i<10?'late':'wrongday');
 const mapelOf=(nama)=> nama.includes('TKJ')?'Administrasi Sistem Jaringan':nama.includes('TSM')?'Sistem Fuel Injection':'Akuntansi Perusahaan Jasa';
 console.log('rombel:', kelasAll.length, '->', kelasAll.map(k=>k.nama+'['+scOf(kelasAll.indexOf(k))+']').join(' '));

 // ---- soal 5/mapel dgn kunci
 const soalPerMapel={};
 for(const mp of ['Administrasi Sistem Jaringan','Sistem Fuel Injection','Akuntansi Perusahaan Jasa']){
   const mid=(await sel(admin,'mata_pelajaran?select=id&nama=eq.'+encodeURIComponent(mp))).b[0].id;
   const rows=[];
   for(const q of [
     {soal:'Soal 1 '+mp+': pilihan tepat?',opsi:['Tepat','Keliru A','Keliru B','Keliru C'],kunci:{index:0,jawaban:'Tepat'},jenis:'pg'},
     {soal:'Soal 2 '+mp+': mana benar?',opsi:['Salah','Benar','Netral','Bohong'],kunci:{index:1,jawaban:'Benar'},jenis:'pg'},
     {soal:'Soal 3 '+mp+': tanpa kunci (manual)?',opsi:['A1','A2','A3','A4'],kunci:null,jenis:'pg'},
     {soal:'Jodoh '+mp+': pasangkan',opsi:['Pas A','Pas B','Pas C'],kunci:{index:0,jawaban:'Pas A'},jenis:'jodoh'},
     {soal:'Esai '+mp+': jelaskan singkat.',opsi:null,kunci:{pedoman:'minimal satu kalimat'},jenis:'essay'},
   ]){const x=await ins(admin,'bank_soal',{mapel_id:mid,guru_id:null,bobot:1,...q});if(!(x.b&&x.b[0])){console.log('FATAL bank',x.s,JSON.stringify(x.b).slice(0,150));process.exit(5);}rows.push(x.b[0].id);}
   soalPerMapel[mp]=rows;
 }
 // ---- jadwal + ujian per kelas
 const ujianOf={}, jadwalToken={};
 for(let i=0;i<kelasAll.length;i++){
   const k=kelasAll[i], sc=scOf(i), mp=mapelOf(k.nama);
   let jm1,jm2,jtgl;
   if(sc==='open'){jm1=hm(-10);jm2=hm(120);jtgl=tgl;}
   else if(sc==='late'){jm1=hm(45);jm2=hm(110);jtgl=tgl;}
   else {jm1=hm(-10);jm2=hm(120);jtgl=besok;}
   const j=await ins(admin,'jadwal_mapel',{kelas_id:k.id,mapel_id:(await sel(admin,'mata_pelajaran?select=id&nama=eq.'+encodeURIComponent(mp))).b[0].id,hari,jam_mulai:jm1,jam_selesai:jm2,keterangan:'BOT'});
   const u=await ins(admin,'ujian',{nama:'BOT '+k.nama,kelas_id:k.id,mapel_id:(await sel(admin,'mata_pelajaran?select=id&nama=eq.'+encodeURIComponent(mp))).b[0].id,guru_id:(await sel(admin,'profiles?select:id&role=eq.guru&limit=1')).b[0].id,soal_list:soalPerMapel[mp],tanggal:jtgl,alokasi_menit:15,token:('BOT'+k.nama.replace(/[^A-Z0-9]/gi,'').toUpperCase().slice(0,5)),status:'aktif',jadwal_id:j.b[0].id},'id,nama');
   if(!(u.b&&u.b[0])){console.log('FATAL ujian',u.s,JSON.stringify(u.b).slice(0,200));process.exit(6);}
   ujianOf[k.id]={id:u.b[0].id,nama:u.b[0].nama,sc,token:'BOT'+k.nama.replace(/[^A-Z0-9]/gi,'').toUpperCase().slice(0,5)};
 }
 const pw=await (await rpc(admin,'admin_daftar_akun_siswa',{})).b;
 const byNis={}; pw.forEach(p=>byNis[p.nis]=p.pw);
 const siswa=(await sel(admin,'siswa?select=id,nis,nama,kelas_id&order=nis')).b;
 console.log('ujian ready:', Object.keys(ujianOf).length);

 // ================= PROBE KEAMANAN =================
 console.log('\n== PROBE ==');
 // ambil siswa kelas0 (open) 2, kelas8(late) 1, kelas10(wrongday) 1 kelas1 anak utk cross
 const clsOpen=kelasAll[0].id, clsLate=kelasAll[8].id, clsWrong=kelasAll[10].id, clsOther=kelasAll[1].id;
 const pick=(cid,n)=>siswa.filter(s=>s.kelas_id===cid).slice(0,n);
 async function stu(nis){
   let g=(stu.g=stu.g||Date.now());
   const now=Date.now(); const wait=g-now; if(wait>0)await sleep(wait);
   stu.g=Math.max(now,g)+240;
   for(let a=0;a<10;a++){
     const res=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:(''+nis).toLowerCase()+'@cbt.local',password:byNis[nis]})});
     if(res.status===200)return (await res.json()).access_token;
     const t=await res.text();
     if(res.status===429){await sleep(4000+a*4000);continue;}
     if(res.status===400)return null;
     await sleep(1500);
   }
   console.log('   login habis retry:',nis);
   return null;}
 const a1=(await pick(clsOpen,3));
 // P1 ghost submit
 const g1=await stu(a1[2].nis);
 const tb=await rpc(g1,'terbitkan_nomor_peserta',{p_ujian:ujianOf[clsOpen].id}); // admin-only → harus 400 (check)
 T('P0 siswa RPC terbitkan → DITOLAK', tb.s===400,(tb.b||{}).message);
 const ps=(await MGMT("select pu.id,sw.nis from public.peserta_ujian pu join public.siswa sw on sw.id=pu.siswa_id where pu.status='belum' limit 1"))[0];
 if(!ps){ // belum ada peserta belom → buat lewat admin rpc
   const tg=await rpc(admin,'terbitkan_nomor_peserta',{p_ujian:ujianOf[clsOpen].id});
   const t=(await MGMT("select pu.id from public.peserta_ujian pu where pu.ujian_id='"+ujianOf[clsOpen].id+"' and pu.status='belum' limit 1"))[0];
   const t1=await stu((await MGMT("select sw.nis from public.peserta_ujian pu join public.siswa sw on sw.id=pu.siswa_id where pu.id='"+t.id+"'"))[0].nis);
   const ghost=await rpc(t1,'kumpulkan_ujian',{p_peserta:t.id});
   T('P1 ghost-submit (belum join) → DITOLAK', ghost.s===400, ghost.b&&(ghost.b.message||JSON.stringify(ghost.b).slice(0,80)));
   const jh=await MGMT("select count(*) n from public.hasil_ujian h where h.peserta_ujian_id='"+t.id+"'");
   T('P1b tidak ada hasil hantu', Number(jh[0].n)===0, jh);
 }
 // P2 cross-class token
 const b1=(await pick(clsOther,1))[0];
 const s2=await stu(b1.nis);
 const xj=await rpc(s2,'cek_token_ujian',{p_ujian:ujianOf[clsOpen].id,p_token:ujianOf[clsOpen].token});
 T('P2 token sah tapi BEDA KELAS → DITOLAK', xj.s===400&&(xj.b||{}).message, (xj.b||{}).message||xj.s);
 // P3 payload 50KB
 const g3=await stu(a1[0].nis);
 const j3=await rpc(g3,'cek_token_ujian',{p_ujian:ujianOf[clsOpen].id,p_token:ujianOf[clsOpen].token});
 let bobs=await rpc(g3,'soal_milik_ujian',{p_peserta:j3.b});
 const long=await rpc(g3,'simpan_jawaban',{p_peserta:j3.b,p_soal:bobs.b.soal[1].id,p_jawaban:'x'.repeat(50000)});
 T('P3 jawaban 50ribu karakter → DITOLAK', long.s===400,(long.b||{}).message||long.s);
 // P4 brute token 15x (catat saja, tidak ada lock)
 let brute400=0, t0=Date.now();
 for(let q=0;q<15;q++){const r=await rpc(g3,'cek_token_ujian',{p_ujian:ujianOf[clsOpen].id,p_token:'AAAA'+q});if(r.s===400)brute400++;}
 console.log('   brute: '+brute400+'/15 ditolak, durasi '+((Date.now()-t0)/1000).toFixed(1)+'s → '+brute400+'/15 (belum rate-limit)');
 // P5 jawab setelah selesai
 await rpc(g3,'simpan_jawaban',{p_peserta:j3.b,p_soal:bobs.b.soal[0].id,p_jawaban:'Tepat'});
 const k1=await rpc(g3,'kumpulkan_ujian',{p_peserta:j3.b});
 const lateAns=await rpc(g3,'simpan_jawaban',{p_peserta:j3.b,p_soal:bobs.b.soal[0].id,p_jawaban:'ubah'});
 T('P5 jawab SETELAH kumpulkan → DITOLAK', lateAns.s===400,(lateAns.b||{}).message);
 const dbl=await rpc(g3,'kumpulkan_ujian',{p_peserta:j3.b});
 T('P6 kumpulkan 2x → DITOLAK', dbl.s===400,(dbl.b||{}).message);
 // reset kelas0 utk wave: hapus peserta g3
 await MGMT("delete from public.jawaban_siswa where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id='"+ujianOf[clsOpen].id+"'); delete from public.hasil_ujian where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id='"+ujianOf[clsOpen].id+"'); delete from public.peserta_ujian where ujian_id='"+ujianOf[clsOpen].id+"';");

 // ================= WAVE 384 =================
 console.log('\n== WAVE ==');
 let done=0, errLogin=0; const res={normal:0,rNormal:0,resume:0,rResume:0,viol:0,rViol:0,dupe:0,rDupe:0,early:0,rEarly:0};
 const ansSet=['Tepat','Benar','A2','Salah','esai jawaban siswa'];
 async function bot(s,i,st){
   try{
    const tok=await stu(s.nis); if(!tok){errLogin++;return;}
    const u=ujianOf[s.kelas_id];
    const list=await rpc(tok,'my_ujian_aktif');
    const appears=(list.b||[]).some(x=>x.id===u.id);
    if(u.sc!=='open'){ // late / wrongday: tidak boleh muncul
      const t=await rpc(tok,'cek_token_ujian',{p_ujian:u.id,p_token:u.token});
      res.early++; if(!appears&&t.s===400)res.rEarly++;
      return;
    }
    if(!appears){return;}
    const jj=await rpc(tok,'cek_token_ujian',{p_ujian:u.id,p_token:u.token});
    if(jj.s!==200){return;}
    const pid=jj.b;
    const mode=i%20;
    if(mode>=0&&mode<14){ // normal
      const so=await rpc(tok,'soal_milik_ujian',{p_peserta:pid});
      const sos=so.b.soal;
      for(let m=0;m<5;m++){const j=await rpc(tok,'simpan_jawaban',{p_peserta:pid,p_soal:sos[m].id,p_jawaban:ansSet[m],p_ragu:mode===13});if(j.s!==200&&j.s!==204)return;}
      const kk=await rpc(tok,'kumpulkan_ujian',{p_peserta:pid});
      const hh=await rpc(tok,'my_hasil');
      const mine=(hh.b||[]).find(x=>x.ujian===u.nama);
      res.normal++;
      const good=kk.s===200&&mine&&Number(mine.nilai)===40&&Number(mine.benar)===2&&Number(mine.salah)===1;
      if(good)res.rNormal++;
      else if(res.normal<=3)console.log('   DMG normal:',s.nis,'k=',kk.s,'mine=',JSON.stringify(mine).slice(0,220));
    } else if(mode<16){ // resume
      const so=await rpc(tok,'soal_milik_ujian',{p_peserta:pid});
      await rpc(tok,'simpan_jawaban',{p_peserta:pid,p_soal:so.b.soal[0].id,p_jawaban:'Tepat'});
      const so2=await rpc(tok,'soal_milik_ujian',{p_peserta:pid});
      const restored=Object.keys(so2.b.jawaban||{}).length===1;
      const sos=so.b.soal;
      for(let m=1;m<5;m++)await rpc(tok,'simpan_jawaban',{p_peserta:pid,p_soal:sos[m].id,p_jawaban:ansSet[m]});
      const kk=await rpc(tok,'kumpulkan_ujian',{p_peserta:pid});
      res.resume++; if(restored&&kk.s===200)res.rResume++;
    } else if(mode<18){ // pelanggar
      await rpc(tok,'catat_pelanggaran',{p_peserta:pid});
      await rpc(tok,'catat_pelanggaran',{p_peserta:pid});
      const so=await rpc(tok,'soal_milik_ujian',{p_peserta:pid});
      const sos=so.b.soal;
      for(let m=0;m<5;m++)await rpc(tok,'simpan_jawaban',{p_peserta:pid,p_soal:sos[m].id,p_jawaban:ansSet[m]});
      const kk=await rpc(tok,'kumpulkan_ujian',{p_peserta:pid});
      const hh=await rpc(tok,'my_hasil');
      const mine=(hh.b||[]).find(x=>x.ujian===u.nama);
      res.viol++; if(kk.s===200&&mine&&Number(mine.pelanggaran)>=2)res.rViol++;
    } else { // double kumpulkan
      const so=await rpc(tok,'soal_milik_ujian',{p_peserta:pid});
      const sos=so.b.soal;
      for(let m=0;m<5;m++)await rpc(tok,'simpan_jawaban',{p_peserta:pid,p_soal:sos[m].id,p_jawaban:ansSet[m]});
      const kk=await rpc(tok,'kumpulkan_ujian',{p_peserta:pid});
      const kk2=await rpc(tok,'kumpulkan_ujian',{p_peserta:pid});
      res.dupe++; if(kk2.s===400)res.rDupe++;
    }
   }catch(e){}
   finally{ if((++done)%50===0)console.log('  wave ' + done + '/' + siswa.length + ' (' + Math.round(performance.now()/1000) + 's)'); }
 }
 const tStart=Date.now();
 let idx=0;
 const CONC=16;
 await Promise.all(Array.from({length:CONC},()=>(async()=>{while(idx<siswa.length){const cur=idx++;await bot(siswa[cur],cur);} })()));
 console.log('wave selesai dalam '+((Date.now()-tStart)/1000).toFixed(0)+'s');

 console.log('\n stats awal wave:', JSON.stringify(res), {errLogin,done});
 console.log('\n== AUDIT DB ==');
 const expJoin=siswa.filter((s,i)=>ujianOf[s.kelas_id]&&ujianOf[s.kelas_id].sc==='open').length;
 const db=await MGMT(
  "select (select count(*) from public.peserta_ujian where status='selesai') selesai,"+
  "(select count(*) from public.jawaban_siswa) jawaban,"+
  "(select count(*) from public.hasil_ujian) hasil,"+
  "(select count(*) from public.hasil_ujian h where h.dinilai and nilai<>40) nilai_salah,"+
  "(select count(*) from (select distinct peserta_ujian_id from public.hasil_ujian) d) hasildistinct,"+
  "(select count(*) from public.peserta_ujian p where p.status='selesai' and not exists(select 1 from public.hasil_ujian h where h.peserta_ujian_id=p.id)) tanpa_hasil,"+
  "(select count(*) from public.jawaban_siswa j where j.soal_id not in (select (unnest(soal_list)) from public.ujian u where u.id=(select ujian_id from public.peserta_ujian where id=j.peserta_ujian_id))) jwb_luar");
 T('W1 semua siswa kelas BUK masuk & selesai', db[0].selesai===expJoin, {selesai:db[0].selesai,expect:expJoin});
 T('W2 jumlah jawaban = masuk×5', Number(db[0].jawaban)===expJoin*5, {jawaban:db[0].jawaban});
 T('W3 tepat satu hasil per peserta', Number(db[0].hasil)===Number(db[0].hasildistinct)&&Number(db[0].hasil)===expJoin, db[0]);
 T('W4 semua nilai konsisten (40, kecuali 0 soal tanpa kunci)', Number(db[0].nilai_salah)===0, db[0].nilai_salah);
 T('W5 tak ada peserta selesai tanpa hasil', Number(db[0].tanpa_hasil)===0);
 T('W6 tak ada jawaban soal luar ujian', Number(db[0].jwb_luar)===0);
 const viol=await MGMT("select count(*) n from public.hasil_ujian where pelanggaran>=2");
 T('W7 pelanggaran tercatat utk pelanggar', Number(viol[0].n)>=res.viol, {viol:res.viol,catat:Number(viol[0].n)});
 const dupe=await MGMT("select count(*) n from public.peserta_ujian where status='selesai' and finished_at is null");
 T('W8 tidak ada status rusak', Number(dupe[0].n)===0);
 console.log('   wave stats:', JSON.stringify(res), {errLogin,done});

 // ================= CLEANUP =================
 for(const [k,v] of Object.entries(ujianOf)) await rpc(admin,'admin_hapus_ujian',{p_ujian:v.id}).catch(()=>{});
 await MGMT("delete from public.jadwal_mapel where keterangan='BOT'; delete from public.bank_soal where mapel_id in (select id from public.mata_pelajaran where nama in ('Administrasi Sistem Jaringan','Sistem Fuel Injection','Akuntansi Perusahaan Jasa'));");
 const fin=await MGMT("select (select count(*) from public.ujian) ujian,(select count(*) from public.peserta_ujian) peserta,(select count(*) from public.jawaban_siswa) jwb,(select count(*) from public.hasil_ujian) hasil,(select count(*) from public.bank_soal) bank,(select count(*) from public.jadwal_mapel) jadwal");
 T('Z0 DB rampung bersih', Number(fin[0].ujian)===0&&Number(fin[0].peserta)===0&&Number(fin[0].jwb)===0&&Number(fin[0].bank)===0, fin[0]);

 console.log('\n============ BOT WARS FINAL ============');
 console.log('PASS '+ok.length+'  FAIL '+bad.length);
 bad.forEach(b=>console.log('  ✗ '+b));
 T.wave=Object.assign(res,{errLogin,done});
 process.exit(bad.length?2:0);
})().catch(e=>{console.error('FATAL',e);process.exit(3)});
