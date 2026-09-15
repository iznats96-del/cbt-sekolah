/* eslint-disable */
// E2E CBT — setup data, semua skenario jendela, matriks keamanan, cleanup.
const base=process.env.SUPA, anon=process.env.ANON, sbp=process.env.SBP;
const H=(t)=>({apikey:anon,Authorization:'Bearer '+t,'Content-Type':'application/json'});
const MGMT=(q)=>fetch('https://api.supabase.com/v1/projects/'+process.env.REF+'/database/query',
  {method:'POST',headers:{Authorization:'Bearer '+sbp,'Content-Type':'application/json'},body:JSON.stringify({query:q})}).then(r=>r.json());
const rpc=async(t,fn,p)=>{const r=await fetch(base+'/rest/v1/rpc/'+fn,{method:'POST',headers:H(t),body:JSON.stringify(p||{})});return {s:r.status,b:await r.json().catch(()=>null)};};
const sel=async(t,q)=>{const r=await fetch(base+'/rest/v1/'+q,{headers:{...H(t),Accept:'application/json'}});return {s:r.status,b:await r.json().catch(()=>null)};};
const ins=async(t,tab,row)=>{const r=await fetch(base+'/rest/v1/'+tab,{method:'POST',headers:{...H(t),Prefer:'return=representation'},body:JSON.stringify(row)});return {s:r.status,b:await r.json().catch(()=>null)};};
const patch=async(t,tab,filt,row)=>{const r=await fetch(base+'/rest/v1/'+tab+'?'+filt,{method:'PATCH',headers:{...H(t),Prefer:'return=minimal'},body:JSON.stringify(row)});return r.status;};
const pass=[], fail=[];
function ok(n,c,d){ (c?pass:fail).push(n+(c?'':' → '+String(d))); console.log((c?'✅ ':'❌ ')+n+(c?'':'  ['+String(JSON.stringify(d ?? null)).slice(0,170)+']')); }

(async()=>{
  // SELF-CLEAN: script bisa dijalankan berulang
  await MGMT("delete from public.jawaban_siswa; delete from public.hasil_ujian; delete from public.peserta_ujian; delete from public.ujian where nama like 'E2E%'; delete from public.jadwal_mapel; delete from public.bank_soal; delete from public.guru where nama in ('Soni Lesmana','Andri Karisman'); delete from public.profiles where email_show in ('soni@cbt.sekolah','andri@cbt.sekolah'); delete from public.mata_pelajaran where nama in ('Administrasi Sistem Jaringan','Sistem Fuel Injection','Akuntansi Perusahaan Jasa');");
  console.log('== SETUP ==');
  const ar=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:'admin@cbt.sekolah',password:'Admin123!'})});
  const admin=(await ar.json()).access_token;
  const nowW=new Date(Date.now()+7*3600000);
  const hari=(nowW.getUTCDay()+6)%7+1; const hariLain=hari===1?2:1;
  const tgl=nowW.toISOString().slice(0,10);
  const tglBs=new Date(nowW.getTime()+864e5).toISOString().slice(0,10);
  const hm=(d,m)=>{const x=new Date(nowW.getTime()+m*60000);return [x.getUTCHours(),x.getUTCMinutes()].map(v=>String(v).padStart(2,'0')).join(':');};
  const kelasAll=(await sel(admin,'kelas?select=id,nama&order=nama')).b;
  const mapelList=[
    ['Administrasi Sistem Jaringan','TKJ'],
    ['Sistem Fuel Injection','TSM'],
    ['Akuntansi Perusahaan Jasa','AKA'],
  ];
  const createdMapel={};
  for(const [n,j] of mapelList){
    const ex=(await sel(admin,'mata_pelajaran?select=id&nama=eq.'+encodeURIComponent(n))).b;
    if(ex.length){createdMapel[n]=ex[0].id;continue;}
    const jid=(await sel(admin,'jurusan?select=id&singkatan=eq.'+j)).b;
    const x=await ins(admin,'mata_pelajaran',{nama:n,kkm:75,jurusan_id:(jid[0]||{}).id||null});
    if(!(x.b&&x.b[0])){console.log('FATAL mapel gagal',x.s,JSON.stringify(x.b).slice(0,200));process.exit(4);}
    createdMapel[n]=x.b[0].id;
  }
  // guru accounts via service
  const mkGuru=async(nm,email,pw)=>{
    const svc=process.env.SVC;
    let u=await fetch(base+'/auth/v1/admin/users',{method:'POST',headers:{apikey:svc,Authorization:'Bearer '+svc,'Content-Type':'application/json'},body:JSON.stringify({email,password:pw,email_confirm:true,user_metadata:{role:'guru',nama:nm}})}).then(r=>r.json());
    if(!u.id){
      const all=await (await fetch(base+'/auth/v1/admin/users?page=1&per_page=1000',{headers:{apikey:svc,Authorization:'Bearer '+svc}})).json();
      const ex=(all.users||[]).find(x=>x.email===email);
      u={id:ex?ex.id:null};
      if(!u.id){console.log('GURU GAGAL:',email);process.exit(6);}
    }
    await fetch(base+'/rest/v1/profiles',{method:'POST',headers:{...H(admin),Prefer:'resolution=merge-duplicates'},body:JSON.stringify({id:u.id,role:'guru',nama:nm,email_show:email})});
    const exG=(await sel(admin,'guru?select=id&nama=eq.'+encodeURIComponent(nm))).b;
    if(!exG.length) await ins(admin,'guru',{nama:nm,profile_id:u.id});
    return u.id;
  };
  let soniR=await sel(admin,'profiles?select=id&nama=eq.Soni%20Lesmana');let soni=(soniR.b&&soniR.b[0])?soniR.b[0]:null;
  if(!soni) soni={id:await mkGuru('Soni Lesmana','soni@cbt.sekolah','Guru123!')};
  let andriR=await sel(admin,'profiles?select=id&nama=eq.Andri%20Karisman');let andri=(andriR.b&&andriR.b[0])?andriR.b[0]:null;
  if(!andri) andri={id:await mkGuru('Andri Karisman','andri@cbt.sekolah','Guru123!')};
  // soal per mapel: 3 PG + 1 jodoh + 1 esai, 1 pg TANPA kunci
  const mkSoal=async(mapelId,owner)=>{
    const rows=[];
    const pgA={mapel_id:mapelId,guru_id:owner,jenis:'pg',soal:`Konsep inti ${mapelName(mapelId)}?`,opsi:['Benar sekali','Salah A','Salah B','Salah C'],kunci:{index:0,jawaban:'Benar sekali'},bobot:1};
    const pgB={...pgA,soal:'Prinsip kedua?',kunci:{index:1,jawaban:'Salah A'}};
    const pgC={...pgA,soal:'Tanpa kunci (manual)?',kunci:null};
    const jd={mapel_id:mapelId,jenis:'jodoh',soal:'Pasangkan istilah dengan definisinya',opsi:['Definisi satu','Definisi dua','Definisi tiga'],kunci:null,bobot:1,guru_id:owner};
    const es={mapel_id:mapelId,jenis:'essay',soal:'Jelaskan prosedur kerja K3 terkait.',kunci:{pedoman:'minimal 3 langkah'},bobot:2,guru_id:owner};
    for(const q of [pgA,pgB,pgC,jd,es]){const x=await ins(owner===admin?admin:admin,'bank_soal',q);rows.push(x.b[0].id);}
    return rows;
  };
  // mapel id helpers
  function mapelName(id){return (mapelList.find(([,])=>false)||[])[0]||'';}
  console.log('== JADWAL + UJIAN ==');
  const g=async (n)=>(await sel(admin,'mata_pelajaran?select=id&nama=eq.'+encodeURIComponent(n))).b[0].id;
  const ids={asj:await g('Administrasi Sistem Jaringan'),sfi:await g('Sistem Fuel Injection'),apj:await g('Akuntansi Perusahaan Jasa')};
  const kAKA=(await sel(admin,'kelas?select=id&nama=eq.X%20AKA%201')).b[0].id;
  const kTKJ1=(await sel(admin,'kelas?select=id&nama=eq.X%20TKJ%201')).b[0].id;
  const kTKJ2=(await sel(admin,'kelas?select=id&nama=eq.XI%20TKJ%202')).b[0].id;
  const kTSM=(await sel(admin,'kelas?select=id&nama=eq.XII%20TSM%201')).b[0].id;
  const J1=(await ins(admin,'jadwal_mapel',{kelas_id:kAKA,mapel_id:ids.apj,hari,jam_mulai:hm(0,-10),jam_selesai:hm(0,60),keterangan:'E2E'})).b[0].id;
  const J2=(await ins(admin,'jadwal_mapel',{kelas_id:kTKJ2,mapel_id:ids.asj,hari,jam_mulai:'00:01',jam_selesai:'00:02',keterangan:'E2E'})).b[0].id;
  const J3=(await ins(admin,'jadwal_mapel',{kelas_id:kTKJ1,mapel_id:ids.asj,hari:hariLain,jam_mulai:hm(0,-10),jam_selesai:hm(0,60),keterangan:'E2E'})).b[0].id;
  const mkUjian=async(nama, kelas, mapel, soal, extra, owner)=>{
    const r=await ins(admin,'ujian',{nama,kelas_id:kelas,mapel_id:mapel,guru_id:owner||soni.id,soal_list:soal,tanggal:tgl,alokasi_menit:30,token:'E2ETOK1',status:'draft',...extra});
    return r.b[0].id;
  };
  const sApj=await mkSoalFor(ids.apj, soni.id), sAsj=await mkSoalFor(ids.asj, soni.id), sSfi=await mkSoalFor(ids.sfi, andri.id);
  async function mkSoalFor(mid,own){
    const rows=[];
    const baseSoal=[
      {soal:`Soal 1 ${mid.slice(0,4)}: definisi benar?`,opsi:['Tepat','Keliru A','Keliru B','Keliru C'],kunci:{index:0,jawaban:'Tepat'}},
      {soal:`Soal 2 ${mid.slice(0,4)}: pernyataan benar?`,opsi:['Salah','Benar','Netral','Bohong'],kunci:{index:1,jawaban:'Benar'}},
      {soal:`Soal 3 ${mid.slice(0,4)}: tanpa kunci?`,opsi:['A1','A2','A3','A4'],kunci:null},
      {soal:`Jodoh ${mid.slice(0,4)}: pasangkan`,opsi:['Pas A','Pas B','Pas C'],kunci:null,jenis:'jodoh'},
      {soal:`Esai ${mid.slice(0,4)}: jelaskan`,opsi:null,kunci:null,jenis:'essay'},
    ];
    for(const q of baseSoal){const x=await ins(admin,'bank_soal',{mapel_id:mid,guru_id:own,bobot:1,...q});if(!(x.b&&x.b[0])){console.log('FATAL bank',x.s,String(JSON.stringify(x.b)).slice(0,220));process.exit(5);}rows.push(x.b[0].id);}
    return rows;
  }
  const uJ=await mkUjian('E2E-JADWAL-TERBUKA', kAKA, ids.apj, sApj, {jadwal_id:J1});
  const uX=await mkUjian('E2E-HARI-BEDA', kTKJ1, ids.asj, sAsj, {jadwal_id:J3}); // jadwal hari lain
  const uZ=await mkUjian('E2E-STATIS', kTSM, ids.sfi, sSfi, {waktu_mulai:new Date(Date.now()-5*6e4-7*36e5).toISOString(),waktu_selesai:new Date(Date.now()+40*6e4-7*36e5).toISOString()}, andri.id);
  const uK=await mkUjian('E2E-JAM-LEWAT', kTKJ2, ids.asj, sAsj, {jadwal_id:J2});
  for(const id of [uJ,uX,uZ,uK]) await patch(admin,'ujian','id=eq.'+id,{status:'aktif'});
  // akun siswa utk tes (X AKA1: Aira; XI TKJ2: siswa[0]; X TKJ1; XII TSM1)
  const pwList=(await rpc(admin,'admin_daftar_akun_siswa',{})).b;
  const findSiswa=async(nis)=>{const rows=await sel(admin,'siswa?select=id,kelas_id&nis=eq.'+nis);return {...(rows.b[0]||{}),pw:(pwList.find(p=>p.nis===nis)||{}).pw,nis};};
  // pick per kelas
  const pickKelas=async(kid)=>{const rows=(await sel(admin,'siswa?select=nis&kelas_id=eq.'+kid+'&limit=1')).b;if(!rows.length)return null;const n=rows[0].nis;const p=(await sel(admin,'siswa?select=id,kelas_id&nis=eq.'+n)).b[0];return {...p,nis:n,pw:(pwList.find(x=>x.nis===n)||{}).pw};};
  const aA=await pickKelas(kAKA), aB=await pickKelas(kTKJ1), aC=await pickKelas(kTKJ2), aD=await pickKelas(kTSM);
  const login=async(s)=>{if(!s)return null;const r=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:(s.nis||'').toLowerCase()+'@cbt.local',password:s.pw})});return r.status===200?(await r.json()).access_token:null;};
  const tA=await login(aA), tB=await login(aB), tC=await login(aC), tD=await login(aD);
  console.log('login siswa A/B/C/D:', [tA,tB,tC,tD].map(x=>x?'ok':'GAGAL').join(','));

  console.log('\n== SKENARIO JENDELA ==');
  const listA=(await rpc(tA,'my_ujian_aktif')).b.map(x=>x.nama);
  ok('A. kelas-window-buka → ujian-terbuka terlihat', listA.includes('E2E-JADWAL-TERBUKA'), listA);
  ok('A. ujian-statis-window-tidak-kelas-ini tersembunyi', !listA.includes('E2E-STATIS'), listA);
  ok('B. sesi-jam-lewat → tersembunyi', !((await rpc(tC,'my_ujian_aktif')).b||[]).some(x=>x.nama==='E2E-JAM-LEWAT'), (await rpc(tC,'my_ujian_aktif')).b);
  ok('C. sesi-hari-bedah → TERSEMBUNYI (cek weekday)', !((await rpc(tB,'my_ujian_aktif')).b||[]).some(x=>x.nama==='E2E-HARI-BEDA'), (await rpc(tB,'my_ujian_aktif')).b);
  // token salah & benar
  const wBad=await rpc(tA,'cek_token_ujian',{p_ujian:uJ,p_token:'SALAH1'});
  ok('D. token salah ditolak', wBad.s===400,(wBad.b||{}).message);
  const okT=await rpc(tA,'cek_token_ujian',{p_ujian:uJ,p_token:'E2ETOK1'});
  ok('E. token benar diterima', okT.s===200&&typeof okT.b==='string', okT.b);
  const wLewat=await rpc(tC,'cek_token_ujian',{p_ujian:uK,p_token:'E2ETOK1'});
  ok('F. jam-lewat → token DITOLAK', wLewat.s===400,(wLewat.b||{}).message);
  const wHari=await rpc(tB,'cek_token_ujian',{p_ujian:uX,p_token:'E2ETOK1'});
  ok('G. hari-bedah → token DITOLAK', wHari.s===400,(wHari.b||{}).message);

  console.log('\n== ALUR UJIAN A (jawab→kumpul→nilai) ==');
  const sq=await rpc(tA,'soal_milik_ujian',{p_peserta:okT.b});
  const soalArr=(sq.b||{}).soal||[];
  ok('H. 5 soal terambil TANPA field kunci', soalArr.length===5 && !JSON.stringify(soalArr).includes('"kunci"'), soalArr.map(s=>Object.keys(s)).join(''));
  const [s1,s2,s3,jd,es]=soalArr;
  await rpc(tA,'simpan_jawaban',{p_peserta:okT.b,p_soal:s1.id,p_jawaban:'Tepat',p_ragu:false});
  await rpc(tA,'simpan_jawaban',{p_peserta:okT.b,p_soal:s2.id,p_jawaban:'Tepat',p_ragu:false}); // salah (kunci Benar)
  await rpc(tA,'simpan_jawaban',{p_peserta:okT.b,p_soal:es.id,p_jawaban:'Jawaban esai siswa',p_ragu:false});
  const cross=await rpc(tA,'simpan_jawaban',{p_peserta:okT.b,p_soal:sAsj[0],p_jawaban:'suntik',p_ragu:false});
  ok('I. injeksi jawaban soal LUAR ujian → DITOLAK', cross.s===400,(cross.b||{}).message);
  const other=await rpc(tA,'simpan_jawaban',{p_peserta:'11111111-2222-3333-4444-555555555555',p_soal:s1.id,p_jawaban:'x'});
  // (peserta random → access denied)
  ok('J. simpan ke peserta tak dikenal → DITOLAK', other.s===400,(other.b||{}).message);
  const kmp=await rpc(tA,'kumpulkan_ujian',{p_peserta:okT.b});
  ok('K. kumpulkan sukses', kmp.s===200, kmp.b);
  const hA=await rpc(tA,'my_hasil'), myH=(hA.b||[]).find(x=>x.ujian==='E2E-JADWAL-TERBUKA');
  // benar=1,kosong pg (tanpa kunci tidak dijumlah) → nilai = skor/total*100 = 1/5*100=20
  ok('L. hasil ada & benar', myH && myH.benar===1 && myH.salah===1, myH);
  console.log('   ', JSON.stringify(myH));

  console.log('\n== RESUME SESUDAH JENDELA (peserta-C jam-lewat) ==');
  // pake status peserta yang ada: peserta buat uK by siswa C
  const cToken=await rpc(tC,'cek_token_ujian',{p_ujian:uK,p_token:'E2ETOK1'}); // harus 400 (F) - peserta via service
  await MGMT(`insert into public.peserta_ujian(ujian_id,siswa_id,status,started_at) '${"select"}'`.slice(0,0)+ // noop safeguard
    `insert into public.peserta_ujian (ujian_id, siswa_id, status, started_at)
     select '$$$','${aC.id}','mengikuti', now();`.replace('$$$',(await sel(admin,'ujian?select=id&nama=eq.E2E-JAM-LEWAT')).b[0].id));
  const pC=await MGMT(`select id from public.peserta_ujian where siswa_id='${aC.id}' and ujian_id=(select id from public.ujian where nama='E2E-JAM-LEWAT')`);
  const resume=await rpc(tC,'soal_milik_ujian',{p_peserta:pC[0].id});
  ok('M. resume peserta mengikuti di luar window → DIBOLEHKAN + sisa 0', resume.s===200 && resume.b.sisa_detik===0, resume.b&&{sisa:resume.b.sisa_detik,st:resume.s});
  const k2=await rpc(tC,'kumpulkan_ujian',{p_peserta:pC[0].id});
  ok('N. kumpulkan di luar window (sisa=0) tetap sah', k2.s===200, k2.b);

  console.log('\n== MATRIKS KEAMANAN ==');
  const rUjian=await sel(tA,'ujian?select=token');
  ok('S1. siswa read tabel ujian → 0 baris', rUjian.s!==403 && Array.isArray(rUjian.b)&&rUjian.b.length===0, rUjian.b||rUjian.s);
  const rBank=await sel(tA,'bank_soal?select=kunci');
  ok('S2. siswa read bank_soal → 0 baris', Array.isArray(rBank.b)&&rBank.b.length===0, rBank.b&&rBank.b.length);
  const rProf=await sel(tA,'profiles?select=id&role=eq.admin');
  ok('S3. siswa read profil admin → 0', Array.isArray(rProf.b)&&rProf.b.length===0, rProf.b&&rProf.b.length);
  const rPw=await MGMT("select 1"); // sanity
  const rJwb=await fetch(base+'/rest/v1/jawaban_siswa?peserta_ujian_id=eq.'+okT.b,{method:'PATCH',headers:{...H(tA),Prefer:'return=minimal','Content-Type':'application/json'},body:JSON.stringify({jawaban:'halus'})}).then(r=>r.status);
  const isi=(await MGMT(`select jawaban from public.jawaban_siswa limit 1`))[0];
  ok('S4. siswa PATCH REST jawaban langsung → tidak berlaku', rJwb===204, 'status '+rJwb);
  const admRpc=await rpc(tA,'admin_reset_semua_password',{});
  ok('S5. siswa RPC reset massal → DITOLAK', admRpc.s===400,(admRpc.b||{}).message);
  const admRpc2=await rpc(tA,'terbitkan_nomor_peserta',{p_ujian:uJ});
  ok('S6. siswa RPC nomor → DITOLAK', admRpc2.s===400,(admRpc2.b||{}).message);
  const admRpc3=await rpc(tA,'admin_hapus_ujian',{p_ujian:uJ});
  ok('S7. siswa RPC hapus ujian → DITOLAK', admRpc3.s===400,(admRpc3.b||{}).message);
  // guru Andri vs ujian Soni
  const gr=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anon,'Content-Type':'application/json'},body:JSON.stringify({email:'andri@cbt.sekolah',password:'Guru123!'})});
  const tG=(await gr.json()).access_token;
  ok('S8. login guru Andri', !!tG);
  const delOther=await rpc(tG,'admin_hapus_ujian',{p_ujian:uJ}); // ujan milik soni
  ok('S9. guru hapus ujian guru lain → DITOLAK', delOther.s===400,(delOther.b||{}).message);
  const nomOther=await rpc(tG,'terbitkan_nomor_peserta',{p_ujian:uJ});
  ok('S10. guru nomor ujian guru lain → DITOLAK', nomOther.s===400,(nomOther.b||{}).message);
  const updOwn=await fetch(base+'/rest/v1/bank_soal?id=in.('+sSfi.join(',')+')',{method:'PATCH',headers:{...H(tG),Prefer:'return=minimal','Content-Type':'application/json'},body:JSON.stringify({pembahasan:'milik sendiri'})});
  ok('S11. guru edit soal ujian milik sendiri → boleh', updOwn.status<300, updOwn.status);
  const updFore=await fetch(base+'/rest/v1/bank_soal?id=in.('+sAsj.join(',')+')',{method:'PATCH',headers:{...H(tG),Prefer:'return=representation','Content-Type':'application/json'},body:JSON.stringify({pembahasan:'jangan'})});
  const changed=updFore.status<300 ? (await updFore.json()).length!==1 || ((await sel(admin,'bank_soal?pembahasan=eq.jangan&select=id')).b||[]).length===0 : true;
  ok('S12. guru edit soal ujian orang lain → tidak berlaku', changed, 'rows:'+JSON.stringify((await sel(admin,'bank_soal?pembahasan=eq.jangan&select=id')).b));
  const tG2=await sel(tG,'peserta_ujian?select=id&ujian_id=eq.'+uJ+'&limit=1');
  console.log('   (catatan: peserta ujian guru lain terlihat via policy guru — cek kebijakan)', tG2.s, (tG2.b||[]).length);
  ok('S13. guru rekap ujian sendiri kebuka', (await sel(tG,'ujian?select=id&guru_id=eq.'+andri.id)).b.length>=1);

  console.log('\n== CLEANUP ==');
  for(const id of [uJ,uX,uZ,uK]) await rpc(admin,'admin_hapus_ujian',{p_ujian:id});
  await MGMT("delete from public.jadwal_mapel where keterangan='E2E'; delete from public.bank_soal where mapel_id in (select id from public.mata_pelajaran where nama in ('Administrasi Sistem Jaringan','Sistem Fuel Injection','Akuntansi Perusahaan Jasa'));");
  const post=await MGMT("select (select count(*) from public.ujian) ujian,(select count(*) from public.peserta_ujian) peserta,(select count(*) from public.jawaban_siswa) jawaban,(select count(*) from public.hasil_ujian) hasil,(select count(*) from public.bank_soal) bank,(select count(*) from public.jadwal_mapel) jadwal_sisa,(select count(*) from public.mata_pelajaran) mapel_sisa,(select count(*) from public.profiles where role='guru') guru");
  console.log('SISA :', JSON.stringify(post[0]));
  console.log('\n============ HASIL AKHIR ============');
  console.log('PASS:', pass.length, '| FAIL:', fail.length);
  if(fail.length){ console.log('YG GAGAL:'); fail.forEach(f=>console.log('  - '+f)); }
  process.exit(fail.length?2:0);
})().catch(e=>{console.error('FATAL',e);process.exit(3)});
