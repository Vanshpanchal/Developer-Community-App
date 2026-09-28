// Seeds the emulator, runs cleanup-profiles.js (dry run, then --apply) and
// prints the result. Run via:
//   firebase emulators:exec --only firestore --project demo-devsphere "node tools/admin/emulator-test.mjs"
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const env = { ...process.env, FIREBASE_PROJECT_ID: 'demo-devsphere' };
initializeApp({ projectId: 'demo-devsphere' });
const db = getFirestore();

await db.doc('User/a').set({ Username: 'a', Email: 'a@x.io', XP: '250' });
await db.doc('User/b').set({ Username: 'b', XP: 90 });
await db.doc('User/c').set({ Username: 'c', Email: 'c@x.io', XP: 'oops' });

const script = join(here, 'cleanup-profiles.js');
for (const args of [['--fix-xp'], ['--apply', '--fix-xp']]) {
  console.log(execFileSync(process.execPath, [script, ...args], { env, encoding: 'utf8' }));
}

const expected = {
  a: { Username: 'a', XP: 250 },
  b: { Username: 'b', XP: 90 },
  c: { Username: 'c', XP: 0 },
};
let ok = true;
for (const [id, want] of Object.entries(expected)) {
  const got = (await db.doc(`User/${id}`).get()).data();
  const pass = JSON.stringify(got) === JSON.stringify(want);
  ok &&= pass;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${id} ${JSON.stringify(got)}`);
}
process.exit(ok ? 0 : 1);
