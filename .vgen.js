
const fs=require('fs');
const env=fs.readFileSync('D:/cbt-sekolah/.env','utf8');
const token=(env.match(/^VERCEL_TOKEN=(.+)$/m)||[])[1].replace(/\r/g,'').trim();
fs.writeFileSync('D:/cbt-sekolah/.vtoken', token);
console.log('OK prefix', token.slice(0,4), 'len', token.length);
