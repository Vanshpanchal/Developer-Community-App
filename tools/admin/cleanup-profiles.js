// One-off profile cleanup for DevSphere (audit SEC-05 / PERF-01).
//
//  - Removes the `Email` field from every User document. Profiles are
//    readable by all signed-in users, and Firebase Auth already stores email.
//  - With --fix-xp, converts legacy string `XP` values to integers.
//
// Usage (from this folder):
//   npm install
//   set GOOGLE_APPLICATION_CREDENTIALS=path\to\service-account.json   (Windows)
//   node cleanup-profiles.js                 # dry run: report only
//   node cleanup-profiles.js --apply         # write changes
//   node cleanup-profiles.js --apply --fix-xp
//
// Get the key from Firebase console > Project settings > Service accounts.
// Keep it out of git and delete it when you are done.
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const apply = process.argv.includes('--apply');
const fixXp = process.argv.includes('--fix-xp');

const projectId = process.env.FIREBASE_PROJECT_ID ?? 'developer-community-app-19742';
// The emulator needs no credentials (and applicationDefault() would hang
// looking for them).
initializeApp(process.env.FIRESTORE_EMULATOR_HOST
  ? { projectId }
  : { credential: applicationDefault(), projectId });
const db = getFirestore();

let scanned = 0;
let emailsRemoved = 0;
let xpFixed = 0;
let writer = db.bulkWriter();

let query = db.collection('User').orderBy('__name__').limit(500);
for (;;) {
  const page = await query.get();
  if (page.empty) break;
  for (const doc of page.docs) {
    scanned++;
    const data = doc.data();
    const update = {};
    if ('Email' in data) {
      update.Email = FieldValue.delete();
      emailsRemoved++;
    }
    if (fixXp && typeof data.XP === 'string') {
      const xp = Number.parseInt(data.XP, 10);
      update.XP = Number.isFinite(xp) && xp >= 0 ? xp : 0;
      xpFixed++;
    }
    if (apply && Object.keys(update).length > 0) writer.update(doc.ref, update);
  }
  query = query.startAfter(page.docs[page.docs.length - 1]);
}
await writer.close();

console.log(`${apply ? 'Updated' : 'Dry run —'} scanned ${scanned} profiles`);
console.log(`  Email fields ${apply ? 'removed' : 'to remove'}: ${emailsRemoved}`);
if (fixXp) console.log(`  String XP values ${apply ? 'converted' : 'to convert'}: ${xpFixed}`);
if (!apply) console.log('Re-run with --apply to write these changes.');
