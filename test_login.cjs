// Test CBT login via fallback path
const email = 'admin@dm1nyp79';
const password = 'Adminyp79#2026';
// Simulate what CBT does: try Supabase auth first, then fallback
// Since Supabase auth has no user, fallback to local PG
console.log('Testing CBT login flow:');
console.log('1. Supabase auth: admin@dm1nyp79 / Adminyp79#2026');
// Actually run the fallback auth from server.js
const { execSync } = require('child_process');
const result = execSync(`cd "D:\cbt-api-cadangan" && curl -s -X POST http://localhost:3000/auth/v1/token -H "Content-Type: application/json" -d '{"email":"${email}","password":"${password}"}'`, { timeout: 10000 });
console.log('\nFallback auth result:');
console.log(result.toString().slice(0,500));
