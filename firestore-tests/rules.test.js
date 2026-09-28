// Firestore security rules tests. Run from this folder with `npm test`
// (starts the Firestore emulator via the Firebase CLI; needs Java).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  collectionGroup,
  deleteDoc,
  getDocs,
  query,
  where,
  deleteField,
  doc,
  getDoc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-devsphere',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'User/alice'), {
      Username: 'alice', Uid: 'alice', XP: 100, Saved: [], Email: 'alice@example.com',
    });
    await setDoc(doc(db, 'User/bob'), { Username: 'bob', Uid: 'bob', XP: '250', Saved: [] });
    await setDoc(doc(db, 'Explore/p1'), {
      Title: 'Q', Description: 'D', Uid: 'alice', uid: 'alice', Report: false,
      likes: [], likescount: 0, code: '', Tags: [],
    });
    await setDoc(doc(db, 'Discussions/d1'), {
      Title: 'T', Description: 'D', Uid: 'alice', Report: false, Tags: [],
      poll: {
        id: 'poll1', question: 'Q?', creatorId: 'alice', createdAt: '2026-01-01T00:00:00.000',
        endsAt: null, allowMultipleVotes: false, isAnonymous: false, showResultsBeforeVoting: false,
        options: [
          { id: 'o1', text: 'A', voterIds: [] },
          { id: 'o2', text: 'B', voterIds: ['carol'] },
        ],
      },
    });
    await setDoc(doc(db, 'Discussions/d1/Replies/r1'), {
      replyId: 'r1', reply: 'answer', uid: 'bob', accepted: false, likes: [], code: '',
    });
    await setDoc(doc(db, 'Secrets/gemini'), { availableModels: ['gemini-2.5-flash'] });
    await setDoc(doc(db, 'Secrets/other'), { apiKey: 'secret' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('SEC-01: no blanket access', () => {
  test('unauthenticated users cannot read posts', async () => {
    await assertFails(getDoc(doc(anon(), 'Explore/p1')));
  });
  test('other users cannot read private tokens', async () => {
    await assertFails(getDoc(doc(as('bob'), 'User/alice/private/tokens')));
    await assertSucceeds(setDoc(doc(as('alice'), 'User/alice/private/tokens'), { fcmTokens: ['t'] }));
  });
  test('users cannot delete someone else\'s post', async () => {
    await assertFails(updateDoc(doc(as('bob'), 'Explore/p1'), { Uid: 'bob', uid: 'bob' }));
    await assertFails(deleteDoc(doc(as('bob'), 'Explore/p1')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'Explore/p1')));
  });
});

describe('SEC-02: content edits', () => {
  test('owner can edit their post content', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), 'Explore/p1'), { Title: 'Edited' }));
  });
  test('others cannot edit, hide or boost a post', async () => {
    await assertFails(updateDoc(doc(as('bob'), 'Explore/p1'), { Title: 'Hacked' }));
    await assertFails(updateDoc(doc(as('bob'), 'Explore/p1'), { Report: true }));
    await assertFails(updateDoc(doc(as('alice'), 'Explore/p1'), { contentStatus: 'approved', qualityScore: 1 }));
  });
  test('posts and discussions must be attributed to the author', async () => {
    const post = { Title: 'x', Description: 'y', Uid: 'alice', uid: 'alice', Report: false, likes: [], likescount: 0, code: '' };
    await assertFails(setDoc(doc(as('bob'), 'Explore/p2'), post));
    await assertSucceeds(setDoc(doc(as('alice'), 'Explore/p2'), post));
    await assertFails(setDoc(doc(as('bob'), 'Discussions/d2'), { Title: 'x', Uid: 'alice', Report: false }));
    await assertSucceeds(setDoc(doc(as('bob'), 'Discussions/d2'), { Title: 'x', Uid: 'bob', Report: false }));
  });
});

describe('BUG-08: likes', () => {
  test('a like adds only the caller and bumps the count by one', async () => {
    const db = as('bob');
    await assertSucceeds(updateDoc(doc(db, 'Explore/p1'), { likes: arrayUnion('bob'), likescount: increment(1) }));
    await assertSucceeds(updateDoc(doc(db, 'Explore/p1'), { likes: arrayRemove('bob'), likescount: increment(-1) }));
  });
  test('cannot like on behalf of others or inflate the count', async () => {
    const db = as('bob');
    await assertFails(updateDoc(doc(db, 'Explore/p1'), { likes: arrayUnion('carol'), likescount: increment(1) }));
    await assertFails(updateDoc(doc(db, 'Explore/p1'), { likescount: increment(5) }));
    await assertFails(updateDoc(doc(db, 'Explore/p1'), { likes: arrayUnion('bob'), likescount: increment(2) }));
  });
  test('reply likes work through the transaction the app uses', async () => {
    const db = as('carol');
    await assertSucceeds(runTransaction(db, async (tx) => {
      await tx.get(doc(db, 'Discussions/d1/Replies/r1'));
      tx.update(doc(db, 'Discussions/d1/Replies/r1'), { likes: arrayUnion('carol') });
    }));
  });
});

describe('Polls', () => {
  test('a user can cast their own vote', async () => {
    const db = as('bob');
    const snap = await getDoc(doc(db, 'Discussions/d1'));
    const poll = snap.data().poll;
    poll.options[0].voterIds = ['bob'];
    await assertSucceeds(updateDoc(doc(db, 'Discussions/d1'), { poll }));
  });
  test('a user cannot add votes for others or rewrite options', async () => {
    const db = as('bob');
    const poll = (await getDoc(doc(db, 'Discussions/d1'))).data().poll;
    const forged = structuredClone(poll);
    forged.options[0].voterIds = ['x', 'y', 'z'];
    await assertFails(updateDoc(doc(db, 'Discussions/d1'), { poll: forged }));
    const renamed = structuredClone(poll);
    renamed.options[1].text = 'Pwned';
    await assertFails(updateDoc(doc(db, 'Discussions/d1'), { poll: renamed }));
    const removed = structuredClone(poll);
    removed.options[1].voterIds = [];
    await assertFails(updateDoc(doc(db, 'Discussions/d1'), { poll: removed }));
  });
});

describe('BUG-03 / SEC-03: gamification writes', () => {
  test('owner subcollections are writable by the owner only', async () => {
    for (const path of [
      'User/alice/gamification/xp_control_2026-09-28', 'User/alice/PortfolioHistory/x',
      'DailyChallenges/2026-09-28/UserChallenges/alice',
      'WeeklyChallenges/2026-W39/UserChallenges/alice', 'User/alice/private/settings',
    ]) {
      await assertSucceeds(setDoc(doc(as('alice'), path), { counts: {} }));
      await assertFails(setDoc(doc(as('bob'), path), { counts: {} }));
      await assertFails(getDoc(doc(as('bob'), path)));
    }
    await assertSucceeds(setDoc(doc(as('alice'), 'User/alice/xp_history/h1'), { xp: 500, action: 'badge' }));
  });
  test('owner XP changes are bounded per write', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), 'User/alice'), { XP: 130 }));
    await assertFails(updateDoc(doc(as('alice'), 'User/alice'), { XP: 999999 }));
    await assertFails(updateDoc(doc(as('alice'), 'User/alice'), { XP: -5 }));
  });
  test('legacy string XP can be converted by an award', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), 'User/bob'), { XP: 260 }));
  });
  test('cross-user award: small XP bump plus a history entry', async () => {
    const db = as('bob');
    const batch = writeBatch(db);
    batch.update(doc(db, 'User/alice'), { XP: 150, lastXpUpdate: serverTimestamp() });
    batch.set(doc(db, 'User/alice/xp_history/h2'), {
      action: 'helpfulAnswer', xp: 50, timestamp: serverTimestamp(), description: 'Answer accepted',
    });
    await assertSucceeds(batch.commit());
  });
  test('cross-user writes cannot exceed the cap or touch other fields', async () => {
    const db = as('bob');
    await assertFails(updateDoc(doc(db, 'User/alice'), { XP: 151 }));
    await assertFails(updateDoc(doc(db, 'User/alice'), { Username: 'pwned' }));
    await assertFails(updateDoc(doc(db, 'User/alice'), { Saved: ['x'] }));
    await assertFails(setDoc(doc(db, 'User/alice/xp_history/h3'), { action: 'x', xp: 5000 }));
    await assertFails(getDoc(doc(db, 'User/alice/xp_history/h1')));
  });
  test('streaks are readable on public profiles; throttle docs are not', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'User/alice/gamification/streak'), { currentStreak: 3 });
      await setDoc(doc(ctx.firestore(), 'User/alice/gamification/xp_control_x'), { counts: {} });
    });
    await assertSucceeds(getDoc(doc(as('bob'), 'User/alice/gamification/streak')));
    await assertFails(getDoc(doc(as('bob'), 'User/alice/gamification/xp_control_x')));
  });
});

describe('SEC-05: profiles', () => {
  test('new profiles cannot store Email or start above 100 XP', async () => {
    await assertFails(setDoc(doc(as('carol'), 'User/carol'), { Username: 'c', Uid: 'carol', XP: 100, Email: 'c@x.io' }));
    await assertFails(setDoc(doc(as('carol'), 'User/carol'), { Username: 'c', Uid: 'carol', XP: 5000 }));
    await assertSucceeds(setDoc(doc(as('carol'), 'User/carol'), { Username: 'c', Uid: 'carol', XP: 100 }));
  });
  test('owners can remove a legacy Email but not change it', async () => {
    await assertFails(updateDoc(doc(as('alice'), 'User/alice'), { Email: 'new@example.com' }));
    await assertSucceeds(updateDoc(doc(as('alice'), 'User/alice'), { Email: deleteField() }));
  });
  test('Uid cannot be changed', async () => {
    await assertFails(updateDoc(doc(as('alice'), 'User/alice'), { Uid: 'bob' }));
  });
});

describe('BUG-07: accepting answers', () => {
  test('only the discussion owner can accept, and only once', async () => {
    await assertFails(updateDoc(doc(as('carol'), 'Discussions/d1/Replies/r1'), { accepted: true }));
    await assertFails(updateDoc(doc(as('bob'), 'Discussions/d1/Replies/r1'), { accepted: true }));
    await assertSucceeds(updateDoc(doc(as('alice'), 'Discussions/d1/Replies/r1'), { accepted: true }));
    await assertFails(updateDoc(doc(as('alice'), 'Discussions/d1/Replies/r1'), { accepted: false }));
  });
  test('reply author can attach code but not self-accept', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), 'Discussions/d1/Replies/r1'), { code: 'print(1)' }));
    await assertFails(updateDoc(doc(as('bob'), 'Discussions/d1/Replies/r1'), { code: 'x', accepted: true }));
  });
  test('nested replies are allowed for their author', async () => {
    await assertSucceeds(setDoc(doc(as('carol'), 'Discussions/d1/Replies/r1/SubReplies/s1'), {
      reply: 'hi', uid: 'carol', likes: [],
    }));
    await assertFails(setDoc(doc(as('carol'), 'Discussions/d1/Replies/r1/SubReplies/s2'), {
      reply: 'hi', uid: 'bob', likes: [],
    }));
  });
});

describe('SEC-09: reporting', () => {
  const report = (uid) => {
    const db = as(uid);
    return runTransaction(db, async (tx) => {
      const d = await tx.get(doc(db, 'Discussions/d1'));
      const count = (d.data().reportCount ?? 0) + 1;
      tx.set(doc(db, `Discussions/d1/Reports/${uid}`), { reporterId: uid, createdAt: serverTimestamp() });
      tx.update(doc(db, 'Discussions/d1'), { reportCount: count, Report: count >= 3 });
    });
  };
  test('one report does not hide content; the third distinct one does', async () => {
    await assertSucceeds(report('bob'));
    await assertSucceeds(report('carol'));
    let snap = await getDoc(doc(as('alice'), 'Discussions/d1'));
    if (snap.data().Report !== false) throw new Error('hidden too early');
    await assertSucceeds(report('dave'));
    snap = await getDoc(doc(as('alice'), 'Discussions/d1'));
    if (snap.data().Report !== true) throw new Error('not hidden after threshold');
  });
  test('the same user cannot report twice or hide content directly', async () => {
    await assertSucceeds(report('bob'));
    await assertFails(report('bob'));
    await assertFails(updateDoc(doc(as('bob'), 'Discussions/d1'), { Report: true }));
  });
});

describe('SEC-04: secrets', () => {
  test('signed-in users can read the model list in Secrets/gemini only', async () => {
    await assertSucceeds(getDoc(doc(as('alice'), 'Secrets/gemini')));
    await assertFails(getDoc(doc(anon(), 'Secrets/gemini')));
    await assertFails(getDoc(doc(as('alice'), 'Secrets/other')));
  });
  test('clients can never write Secrets', async () => {
    await assertFails(setDoc(doc(as('alice'), 'Secrets/gemini'), { availableModels: [] }));
  });
});

describe('SEC-08: deletion and blocking', () => {
  test("a discussion owner can delete other users' replies in their thread", async () => {
    await assertFails(deleteDoc(doc(as('carol'), 'Discussions/d1/Replies/r1')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'Discussions/d1/Replies/r1')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'Discussions/d1')));
  });
  test('reply authors can find and delete their replies across discussions', async () => {
    const db = as('bob');
    const mine = await assertSucceeds(getDocs(query(collectionGroup(db, 'Replies'), where('uid', '==', 'bob'))));
    if (mine.size !== 1) throw new Error(`expected 1 reply, got ${mine.size}`);
    await assertSucceeds(deleteDoc(mine.docs[0].ref));
  });
  test('challenge progress is only queryable by its owner', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'DailyChallenges/2026-09-28/UserChallenges/alice'), { userId: 'alice' });
    });
    await assertSucceeds(getDocs(query(collectionGroup(as('alice'), 'UserChallenges'), where('userId', '==', 'alice'))));
    await assertFails(getDocs(query(collectionGroup(as('bob'), 'UserChallenges'), where('userId', '==', 'alice'))));
    await assertFails(getDocs(collectionGroup(as('bob'), 'UserChallenges')));
  });
  test('the block list is private and a profile can be deleted by its owner', async () => {
    await assertSucceeds(setDoc(doc(as('alice'), 'User/alice/private/blocked'), { uids: ['bob'] }));
    await assertFails(getDoc(doc(as('bob'), 'User/alice/private/blocked')));
    await assertFails(deleteDoc(doc(as('bob'), 'User/alice')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'User/alice')));
  });
  test("account deletion can withdraw the user's likes", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'Explore/p1'), { likes: ['bob'], likescount: 1 });
    });
    await assertSucceeds(updateDoc(doc(as('bob'), 'Explore/p1'), { likes: arrayRemove('bob'), likescount: increment(-1) }));
  });
});

describe('BUG-05: minimum version config', () => {
  test('Config/app is readable before sign-in but never writable', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'Config/app'), { minSupportedVersionCode: 9 });
      await setDoc(doc(ctx.firestore(), 'Config/other'), { x: 1 });
    });
    await assertSucceeds(getDoc(doc(anon(), 'Config/app')));
    await assertFails(getDoc(doc(anon(), 'Config/other')));
    await assertFails(setDoc(doc(as('alice'), 'Config/app'), { minSupportedVersionCode: 1 }));
  });
});
