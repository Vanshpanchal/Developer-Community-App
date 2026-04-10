const admin = require('firebase-admin');

let firebaseInitialized = false;

const BLOCKED_PATTERNS = [
    /\bkill yourself\b/i,
    /\bhurt yourself\b/i,
    /\bsuicide\b/i,
    /\bself\s*harm\b/i,
    /\bbomb threat\b/i,
    /\bshoot up\b/i,
    /\brape\b/i,
    /\bporn\b/i,
    /\bnudes?\b/i,
    /\bgo back to your country\b/i,
];

function env(name, fallback = '') {
    return process.env[name] || fallback;
}

function initializeFirebase() {
    if (firebaseInitialized) return;

    const projectId = env('FIREBASE_PROJECT_ID');
    const clientEmail = env('FIREBASE_CLIENT_EMAIL');
    const privateKeyRaw = env('FIREBASE_PRIVATE_KEY');

    if (!projectId || !clientEmail || !privateKeyRaw) {
        throw new Error('Missing Firebase service account env vars. Required: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY');
    }

    const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

    admin.initializeApp({
        credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey,
        }),
    });

    firebaseInitialized = true;
}

function parseBody(req) {
    if (!req || req.body == null) return {};
    if (typeof req.body === 'string') {
        try {
            return JSON.parse(req.body);
        } catch {
            return {};
        }
    }
    if (typeof req.body === 'object') return req.body;
    return {};
}

function routeKey(req) {
    const method = (req?.method || 'GET').toUpperCase();
    const path = (req?.path || '/').toLowerCase();
    return `${method} ${path}`;
}

function getApiKey(req, body) {
    const headers = req?.headers || {};
    const lowerHeaders = Object.fromEntries(
        Object.entries(headers).map(([k, v]) => [k.toLowerCase(), String(v)]),
    );

    const xApiKey = lowerHeaders['x-api-key'];
    if (xApiKey && xApiKey.trim()) return xApiKey.trim();

    const auth = lowerHeaders['authorization'];
    if (auth && auth.startsWith('Bearer ')) return auth.slice(7).trim();
    if (auth && auth.trim()) return auth.trim();

    if (typeof body?.apiKey === 'string') return body.apiKey.trim();
    return '';
}

function unauthorized(res) {
    return res.json({ success: false, message: 'Unauthorized' }, 401);
}

function validateText(value, field, min, max) {
    const text = (value ?? '').toString().trim();
    if (!text) throw new Error(`${field} is required`);
    if (text.length < min) throw new Error(`${field} must be at least ${min} characters`);
    if (text.length > max) throw new Error(`${field} must be less than ${max} characters`);
    return text;
}

function normalizeDataMap(rawData) {
    const data = rawData && typeof rawData === 'object' ? rawData : {};
    return Object.fromEntries(
        Object.entries(data).map(([k, v]) => [String(k), String(v)]),
    );
}

function collectUserTokens(data) {
    const out = new Set();
    const single = [data?.fcmToken, data?.notificationToken, data?.deviceToken, data?.pushToken];
    const lists = [data?.fcmTokens, data?.notificationTokens, data?.deviceTokens, data?.pushTokens];

    for (const token of single) {
        if (typeof token === 'string' && token.trim().length >= 20) out.add(token.trim());
    }

    for (const list of lists) {
        if (!Array.isArray(list)) continue;
        for (const item of list) {
            if (typeof item === 'string' && item.trim().length >= 20) out.add(item.trim());
        }
    }

    return [...out];
}

async function fetchAllUserTokens(maxUsers = 10000) {
    const db = admin.firestore();
    const pageSize = 500;
    let scanned = 0;
    let lastDoc = null;
    const all = new Set();

    while (scanned < maxUsers) {
        let query = db
            .collection('User')
            .orderBy(admin.firestore.FieldPath.documentId(), 'asc')
            .limit(pageSize);

        if (lastDoc) query = query.startAfter(lastDoc);

        const snap = await query.get();
        if (snap.empty) break;

        for (const doc of snap.docs) {
            scanned += 1;
            for (const token of collectUserTokens(doc.data())) all.add(token);
            if (scanned >= maxUsers) break;
        }

        lastDoc = snap.docs[snap.docs.length - 1];
        if (snap.size < pageSize) break;
    }

    return { tokens: [...all], scannedUsers: scanned };
}

async function sendSingleFcm({ title, body, token, data = {}, dryRun = false }) {
    const response = await admin.messaging().send(
        {
            notification: { title, body },
            data: normalizeDataMap(data),
            token,
        },
        dryRun,
    );

    return response;
}

async function sendBroadcastFcm({ title, body, tokens, data = {}, dryRun = false }) {
    const chunkSize = 500;
    let successCount = 0;
    let failureCount = 0;
    const errors = [];

    for (let i = 0; i < tokens.length; i += chunkSize) {
        const chunk = tokens.slice(i, i + chunkSize);
        const result = await admin.messaging().sendEachForMulticast(
            {
                notification: { title, body },
                data: normalizeDataMap(data),
                tokens: chunk,
            },
            dryRun,
        );

        successCount += result.successCount;
        failureCount += result.failureCount;

        result.responses.forEach((entry, idx) => {
            if (entry.success || errors.length >= 25) return;
            errors.push({ token: chunk[idx], error: entry.error?.message || 'Unknown FCM error' });
        });
    }

    return { successCount, failureCount, errors };
}

function containsBlockedContent(text) {
    return BLOCKED_PATTERNS.some((pattern) => pattern.test(text));
}

function hasRepeatedCharacters(text) {
    return /(.)\1{4,}/i.test(text);
}

function hasRepeatedWords(text) {
    return /\b(\w+)(?:\s+\1\b){2,}/i.test(text);
}

function looksLikeGibberish(text) {
    const tokens = text.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
    if (!tokens.length) return true;

    const longTokens = tokens.filter((token) => token.length >= 4);
    if (!longTokens.length) return false;

    const gibberishTokens = longTokens.filter((token) => {
        const uniqueChars = new Set(token.split('')).size;
        const hasVowel = /[aeiou]/.test(token);
        const uniqueRatio = uniqueChars / token.length;
        return !hasVowel || uniqueRatio < 0.35;
    }).length;

    const uniqueWords = new Set(tokens).size;
    if (text.length >= 12 && uniqueWords <= 2) return true;

    return gibberishTokens / longTokens.length >= 0.6;
}

function qualityScoreForText(text, minLength) {
    let score = 1.0;
    const trimmed = text.trim();
    const uniqueWords = new Set(trimmed.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean)).size;

    if (trimmed.length < minLength) score -= 0.35;
    if (hasRepeatedCharacters(trimmed)) score -= 0.3;
    if (hasRepeatedWords(trimmed)) score -= 0.25;
    if (looksLikeGibberish(trimmed)) score -= 0.4;
    if (trimmed.length >= minLength && uniqueWords <= 2) score -= 0.2;

    return Math.max(0, Math.min(1, score));
}

function heuristicModeration({ title, description, tags = [], code = '' }) {
    const combined = [title, description, ...tags, code].join(' ').trim();

    if (containsBlockedContent(combined)) {
        return {
            status: 'blocked',
            qualityScore: 0,
            flags: ['blocked_language'],
            source: 'heuristic',
            userMessage: 'Please remove harmful, abusive, or unsafe language before posting.',
        };
    }

    const flags = [];
    if (title.length < 8) flags.push('title_too_short');
    if (description.length < 20) flags.push('description_too_short');
    if (!tags.length) flags.push('missing_tags');
    if (hasRepeatedCharacters(combined)) flags.push('repeated_characters');
    if (hasRepeatedWords(combined)) flags.push('repeated_words');
    if (looksLikeGibberish(combined)) flags.push('gibberish');

    const titleScore = qualityScoreForText(title, 5);
    const descriptionScore = qualityScoreForText(description, 12);
    let qualityScore = titleScore * 0.35 + descriptionScore * 0.65;
    if (!tags.length) qualityScore -= 0.1;
    qualityScore = Math.max(0, Math.min(1, qualityScore));

    const lowQuality = flags.length > 0 || qualityScore < 0.7;
    return {
        status: lowQuality ? 'low_quality' : 'approved',
        qualityScore: lowQuality ? Math.min(qualityScore, 0.69) : qualityScore,
        flags: [...new Set(flags)].sort(),
        source: 'heuristic',
        userMessage: lowQuality
            ? 'Please enter meaningful text. Random, repetitive, or unclear phrases are not allowed.'
            : 'Looks good.',
    };
}

async function runGeminiModeration(payload) {
    const apiKey = env('GEMINI_API_KEY');
    const geminiEndpoint = env('GEMINI_ENDPOINT');
    if (!apiKey || !geminiEndpoint) return null;

    const prompt = `You are a moderation classifier for a professional developer community app. Return ONLY JSON: {"status":"approved|low_quality|blocked","qualityScore":0.0,"flags":["string"],"userMessage":"short"}. Content: ${JSON.stringify(payload)}`;

    const response = await fetch(geminiEndpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
        },
        body: JSON.stringify({
            safetySettings: [
                { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_LOW_AND_ABOVE' },
                { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_LOW_AND_ABOVE' },
                { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_LOW_AND_ABOVE' },
                { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_LOW_AND_ABOVE' },
            ],
            generationConfig: {
                temperature: 0.1,
                maxOutputTokens: 220,
                responseMimeType: 'application/json',
            },
            contents: [{ parts: [{ text: prompt }] }],
        }),
    });

    if (!response.ok) return null;

    const json = await response.json();
    const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text || typeof text !== 'string') return null;

    try {
        const parsed = JSON.parse(text);
        return {
            status: ['approved', 'low_quality', 'blocked'].includes(parsed?.status)
                ? parsed.status
                : 'low_quality',
            qualityScore: Math.max(0, Math.min(1, Number(parsed?.qualityScore ?? 0.5))),
            flags: Array.isArray(parsed?.flags)
                ? parsed.flags.map((item) => String(item)).filter(Boolean)
                : [],
            source: 'gemini',
            userMessage:
                typeof parsed?.userMessage === 'string' && parsed.userMessage.trim()
                    ? parsed.userMessage.trim()
                    : 'Content reviewed.',
        };
    } catch {
        return null;
    }
}

function mergeModeration(heuristic, ai) {
    if (!ai) return heuristic;
    if (heuristic.status === 'blocked' || ai.status === 'blocked') {
        return {
            status: 'blocked',
            qualityScore: 0,
            flags: [...new Set([...(heuristic.flags || []), ...(ai.flags || [])])],
            source: 'hybrid',
            userMessage: ai.userMessage || 'Please remove harmful content before posting.',
        };
    }

    const qualityScore = Math.max(
        0,
        Math.min(1, heuristic.qualityScore * 0.45 + ai.qualityScore * 0.55),
    );
    const lowQuality =
        heuristic.status === 'low_quality' || ai.status === 'low_quality' || qualityScore < 0.7;

    return {
        status: lowQuality ? 'low_quality' : 'approved',
        qualityScore: lowQuality ? Math.min(qualityScore, 0.69) : qualityScore,
        flags: [...new Set([...(heuristic.flags || []), ...(ai.flags || [])])],
        source: 'hybrid',
        userMessage: lowQuality ? (ai.userMessage || 'Please improve content quality.') : 'Looks good.',
    };
}

function buildSubmissionPayload(data) {
    return {
        title: (data?.Title ?? data?.title ?? '').toString().trim(),
        description: (data?.Description ?? data?.description ?? '').toString().trim(),
        tags: Array.isArray(data?.Tags ?? data?.tags)
            ? (data.Tags ?? data.tags).map((tag) => String(tag).trim()).filter(Boolean).slice(0, 12)
            : [],
        code: (data?.code ?? '').toString().trim().slice(0, 12000),
    };
}

async function moderateTodayCollection(collectionName) {
    const db = admin.firestore();
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    const snap = await db
        .collection(collectionName)
        .where('Timestamp', '>=', admin.firestore.Timestamp.fromDate(start))
        .where('Timestamp', '<', admin.firestore.Timestamp.fromDate(end))
        .get();

    let updated = 0;
    for (const doc of snap.docs) {
        const payload = buildSubmissionPayload(doc.data());
        if (!payload.title || !payload.description) continue;

        const heuristic = heuristicModeration(payload);
        const ai = await runGeminiModeration({ scope: 'submission', ...payload });
        const result = mergeModeration(heuristic, ai);

        const updateData = {
            qualityScore: result.qualityScore,
            contentStatus: result.status,
            deprioritizeInFeed: result.status === 'low_quality' || result.qualityScore < 0.7,
            moderationFlags: result.flags,
            moderationSource: result.source,
            moderationLastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (result.status === 'blocked') updateData.Report = true;

        await doc.ref.update(updateData);
        updated += 1;
    }

    return { scanned: snap.size, updated };
}

module.exports = async ({ req, res, log, error }) => {
    try {
        initializeFirebase();

        const body = parseBody(req);
        const expectedApiKey = env('INTERNAL_API_KEY');
        const requestApiKey = getApiKey(req, body);

        if (!expectedApiKey || requestApiKey !== expectedApiKey) {
            return unauthorized(res);
        }

        const route = routeKey(req);

        if (route === 'POST /fcm/send') {
            const title = validateText(body?.title, 'title', 1, 120);
            const messageBody = validateText(body?.body, 'body', 1, 300);
            const token = validateText(body?.token, 'token', 20, 4096);
            const data = normalizeDataMap(body?.data);
            const dryRun = body?.dryRun === true;

            const response = await sendSingleFcm({
                title,
                body: messageBody,
                token,
                data,
                dryRun,
            });

            return res.json(
                {
                    success: true,
                    message: dryRun ? 'Dry run successful' : 'Notification sent successfully',
                    response,
                },
                200,
            );
        }

        if (route === 'POST /fcm/broadcast') {
            const title = validateText(body?.title, 'title', 1, 120);
            const messageBody = validateText(body?.body, 'body', 1, 300);
            const data = normalizeDataMap(body?.data);
            const dryRun = body?.dryRun === true;

            const providedTokens = Array.isArray(body?.tokens)
                ? body.tokens.map((item) => String(item).trim()).filter((item) => item.length >= 20)
                : [];

            let tokens = [...new Set(providedTokens)];
            let scannedUsers = 0;

            if (!tokens.length) {
                const fetched = await fetchAllUserTokens(Number(body?.maxUsers || 10000));
                tokens = fetched.tokens;
                scannedUsers = fetched.scannedUsers;
            }

            if (!tokens.length) {
                return res.json(
                    {
                        success: true,
                        message: 'No FCM tokens found to broadcast',
                        sentCount: 0,
                        failedCount: 0,
                        scannedUsers,
                    },
                    200,
                );
            }

            const result = await sendBroadcastFcm({
                title,
                body: messageBody,
                tokens,
                data,
                dryRun,
            });

            return res.json(
                {
                    success: result.failureCount === 0,
                    message: dryRun ? 'Broadcast dry run completed' : 'Broadcast completed',
                    totalTokens: tokens.length,
                    sentCount: result.successCount,
                    failedCount: result.failureCount,
                    scannedUsers,
                    errors: result.errors,
                },
                200,
            );
        }

        if (route === 'POST /moderation/check') {
            const payload = {
                title: validateText(body?.title, 'title', 3, 180),
                description: validateText(body?.description, 'description', 8, 4000),
                tags: Array.isArray(body?.tags)
                    ? body.tags.map((tag) => String(tag).trim()).filter(Boolean).slice(0, 12)
                    : [],
                code: (body?.code ?? '').toString().trim().slice(0, 12000),
            };

            const heuristic = heuristicModeration(payload);
            const ai = await runGeminiModeration({ scope: 'submission', ...payload });
            const result = mergeModeration(heuristic, ai);

            return res.json({ success: true, moderation: result }, 200);
        }

        if (route === 'POST /moderation/daily') {
            const explore = await moderateTodayCollection('Explore');
            const discussions = await moderateTodayCollection('Discussions');

            return res.json(
                {
                    success: true,
                    message: 'Daily moderation completed',
                    explore,
                    discussions,
                },
                200,
            );
        }

        return res.json(
            {
                success: false,
                message: 'Route not found. Use POST /fcm/send, /fcm/broadcast, /moderation/check, /moderation/daily',
            },
            404,
        );
    } catch (err) {
        if (error) error(`Function error: ${err.message}`);
        if (log) log(err.stack || String(err));
        return res.json(
            {
                success: false,
                message: 'Error processing request',
                error: err.message,
            },
            500,
        );
    }
};
