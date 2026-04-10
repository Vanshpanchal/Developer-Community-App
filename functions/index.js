const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

admin.initializeApp();

const geminiApiKey = defineSecret('GEMINI_API_KEY');
const internalFcmApiKey = defineSecret('INTERNAL_FCM_API_KEY');

const MODERATION_MODEL_ENDPOINT =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent';

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

function validateText(value, fieldName, min, max) {
    const text = (value ?? '').toString().trim();
    if (!text) {
        throw new HttpsError('invalid-argument', `${fieldName} is required.`);
    }
    if (text.length < min) {
        throw new HttpsError(
            'invalid-argument',
            `${fieldName} must be at least ${min} characters.`,
        );
    }
    if (text.length > max) {
        throw new HttpsError(
            'invalid-argument',
            `${fieldName} must be less than ${max} characters.`,
        );
    }
    return text;
}

function parseRequestBody(req) {
    if (!req || req.body == null) return {};
    if (typeof req.body === 'string') {
        try {
            return JSON.parse(req.body);
        } catch {
            return {};
        }
    }
    if (typeof req.body === 'object') {
        return req.body;
    }
    return {};
}

function getApiKeyFromRequest(req) {
    const apiHeader = req.get('x-api-key');
    if (apiHeader && apiHeader.trim()) return apiHeader.trim();

    const authHeader = req.get('authorization') || req.get('Authorization');
    if (!authHeader) return '';

    const bearerPrefix = 'Bearer ';
    if (authHeader.startsWith(bearerPrefix)) {
        return authHeader.slice(bearerPrefix.length).trim();
    }

    return authHeader.trim();
}

function writeJson(res, status, payload) {
    res.status(status).json(payload);
}

function normalizeDataMap(rawData) {
    const data = rawData && typeof rawData === 'object' ? rawData : {};
    return Object.fromEntries(
        Object.entries(data).map(([k, v]) => [String(k), String(v)]),
    );
}

function collectUserTokens(data) {
    const candidateFields = [
        data?.fcmToken,
        data?.notificationToken,
        data?.deviceToken,
        data?.pushToken,
    ];

    const candidateLists = [
        data?.fcmTokens,
        data?.notificationTokens,
        data?.deviceTokens,
        data?.pushTokens,
    ];

    const tokenSet = new Set();

    for (const value of candidateFields) {
        if (typeof value === 'string' && value.trim().length >= 20) {
            tokenSet.add(value.trim());
        }
    }

    for (const list of candidateLists) {
        if (!Array.isArray(list)) continue;
        for (const item of list) {
            if (typeof item === 'string' && item.trim().length >= 20) {
                tokenSet.add(item.trim());
            }
        }
    }

    return [...tokenSet];
}

async function fetchAllUserTokens({ maxUsers = 10000 }) {
    const db = admin.firestore();
    const pageSize = 500;
    let lastDoc = null;
    let scannedUsers = 0;
    const tokenSet = new Set();

    while (scannedUsers < maxUsers) {
        let query = db
            .collection('User')
            .orderBy(admin.firestore.FieldPath.documentId(), 'asc')
            .limit(pageSize);
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();
        if (snapshot.empty) break;

        for (const doc of snapshot.docs) {
            scannedUsers += 1;
            const tokens = collectUserTokens(doc.data());
            for (const token of tokens) tokenSet.add(token);
            if (scannedUsers >= maxUsers) break;
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < pageSize) break;
    }

    return {
        tokens: [...tokenSet],
        scannedUsers,
    };
}

async function sendMulticastInChunks({ tokens, title, body, data, dryRun = false }) {
    let successCount = 0;
    let failureCount = 0;
    const errors = [];
    const chunkSize = 500;

    for (let index = 0; index < tokens.length; index += chunkSize) {
        const chunk = tokens.slice(index, index + chunkSize);
        const response = await admin.messaging().sendEachForMulticast(
            {
                notification: { title, body },
                data,
                tokens: chunk,
            },
            dryRun,
        );

        successCount += response.successCount;
        failureCount += response.failureCount;

        response.responses.forEach((entry, itemIndex) => {
            if (entry.success) return;
            if (errors.length >= 25) return;
            errors.push({
                token: chunk[itemIndex],
                error: entry.error?.message || 'Unknown FCM error',
            });
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
    const tokens = text
        .toLowerCase()
        .split(/[^a-z0-9]+/)
        .filter(Boolean);

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
    const uniqueWords = new Set(
        trimmed
            .toLowerCase()
            .split(/[^a-z0-9]+/)
            .filter(Boolean),
    ).size;

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
            userMessage:
                'Please remove harmful, abusive, or unsafe language before posting.',
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

    const isLowQuality = flags.length > 0 || qualityScore < 0.7;

    return {
        status: isLowQuality ? 'low_quality' : 'approved',
        qualityScore: isLowQuality ? Math.min(qualityScore, 0.69) : qualityScore,
        flags: [...new Set(flags)].sort(),
        source: 'heuristic',
        userMessage: isLowQuality
            ? 'Please enter meaningful text. Random, repetitive, or unclear phrases are not allowed.'
            : 'Looks good.',
    };
}

function heuristicReplyModeration(reply) {
    if (containsBlockedContent(reply)) {
        return {
            status: 'blocked',
            qualityScore: 0,
            flags: ['blocked_language'],
            source: 'heuristic',
            userMessage:
                'Please remove harmful, abusive, or unsafe language before posting.',
        };
    }

    const flags = [];
    if (reply.trim().length < 6) flags.push('too_short');
    if (hasRepeatedCharacters(reply)) flags.push('repeated_characters');
    if (hasRepeatedWords(reply)) flags.push('repeated_words');
    if (looksLikeGibberish(reply)) flags.push('gibberish');

    let qualityScore = qualityScoreForText(reply, 6);
    const words = reply.trim().split(/\s+/).filter(Boolean).length;
    if (words < 3) qualityScore = Math.max(0, qualityScore - 0.2);

    const lowQuality = flags.length > 0 || qualityScore < 0.55;
    return {
        status: lowQuality ? 'low_quality' : 'approved',
        qualityScore: lowQuality ? Math.min(qualityScore, 0.69) : qualityScore,
        flags: [...new Set(flags)].sort(),
        source: 'heuristic',
        userMessage: lowQuality
            ? 'Please make your reply clearer and more meaningful.'
            : 'Looks good.',
    };
}

async function runGeminiModeration({ apiKey, payload }) {
    const prompt = `You are a moderation classifier for a professional developer community app.\n\nModeration goals:\n1) Block harmful content: hate speech, harassment, threats, violent incitement, self-harm encouragement, sexually explicit abuse, or dangerous instructions.\n2) Mark low_quality content when it is mostly random, meaningless, gibberish, repetitive spam, or clearly irrelevant to a developer community discussion.\n3) Do not penalize technical jargon, stack traces, code snippets, library names, abbreviations, or short tags if still meaningful.\n\nReturn ONLY JSON in this exact shape:\n{\n  \"status\": \"approved\" | \"low_quality\" | \"blocked\",\n  \"qualityScore\": 0.0,\n  \"flags\": [\"string\"],\n  \"userMessage\": \"short message for the end user\"\n}\n\nContent to review:\n${JSON.stringify(payload)}`;

    const response = await fetch(MODERATION_MODEL_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
        },
        body: JSON.stringify({
            safetySettings: [
                {
                    category: 'HARM_CATEGORY_HATE_SPEECH',
                    threshold: 'BLOCK_LOW_AND_ABOVE',
                },
                {
                    category: 'HARM_CATEGORY_HARASSMENT',
                    threshold: 'BLOCK_LOW_AND_ABOVE',
                },
                {
                    category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
                    threshold: 'BLOCK_LOW_AND_ABOVE',
                },
                {
                    category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                    threshold: 'BLOCK_LOW_AND_ABOVE',
                },
            ],
            generationConfig: {
                temperature: 0.1,
                maxOutputTokens: 220,
                responseMimeType: 'application/json',
            },
            contents: [{ parts: [{ text: prompt }] }],
        }),
    });

    if (!response.ok) {
        logger.warn('Gemini moderation failed', {
            status: response.status,
            statusText: response.statusText,
        });
        return null;
    }

    const json = await response.json();
    const parts = json?.candidates?.[0]?.content?.parts;
    const rawText = parts?.[0]?.text;
    if (!rawText || typeof rawText !== 'string') {
        return null;
    }

    try {
        const parsed = JSON.parse(rawText);
        const status = ['approved', 'low_quality', 'blocked'].includes(parsed?.status)
            ? parsed.status
            : 'low_quality';
        const qualityScore = Math.max(
            0,
            Math.min(1, Number(parsed?.qualityScore ?? 0.5)),
        );
        const flags = Array.isArray(parsed?.flags)
            ? parsed.flags.map((item) => String(item)).filter(Boolean)
            : [];

        return {
            status,
            qualityScore,
            flags,
            source: 'gemini',
            userMessage:
                typeof parsed?.userMessage === 'string' && parsed.userMessage.trim()
                    ? parsed.userMessage.trim()
                    : status === 'blocked'
                        ? 'Please remove harmful content before posting.'
                        : status === 'low_quality'
                            ? 'Please make your post clearer and more meaningful.'
                            : 'Looks good.',
        };
    } catch (e) {
        logger.warn('Could not parse Gemini JSON moderation output', { error: String(e) });
        return null;
    }
}

function mergeModeration(heuristic, ai) {
    if (!ai) return heuristic;

    if (heuristic.status === 'blocked' || ai.status === 'blocked') {
        return {
            status: 'blocked',
            qualityScore: 0,
            flags: [...new Set([...(heuristic.flags || []), ...(ai.flags || [])])].sort(),
            source: 'hybrid',
            userMessage:
                ai.userMessage ||
                'Please remove harmful, abusive, or unsafe language before posting.',
        };
    }

    const qualityScore = Math.max(
        0,
        Math.min(1, heuristic.qualityScore * 0.45 + ai.qualityScore * 0.55),
    );
    const isLowQuality =
        heuristic.status === 'low_quality' || ai.status === 'low_quality' || qualityScore < 0.7;

    return {
        status: isLowQuality ? 'low_quality' : 'approved',
        qualityScore: isLowQuality ? Math.min(qualityScore, 0.69) : qualityScore,
        flags: [...new Set([...(heuristic.flags || []), ...(ai.flags || [])])].sort(),
        source: 'hybrid',
        userMessage: isLowQuality
            ? ai.userMessage ||
            'Please make your post clearer and more meaningful for the community.'
            : 'Looks good.',
    };
}

function buildSubmissionPayloadFromDoc(data) {
    const title = (data?.Title ?? '').toString().trim();
    const description = (data?.Description ?? '').toString().trim();
    const tags = Array.isArray(data?.Tags)
        ? data.Tags.map((tag) => String(tag).trim()).filter(Boolean).slice(0, 12)
        : [];
    const code = (data?.code ?? '').toString().trim().slice(0, 12000);

    return { title, description, tags, code };
}

async function moderateCollectionForToday(collectionName, apiKey) {
    const db = admin.firestore();

    const start = new Date();
    start.setHours(0, 0, 0, 0);

    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    const snapshot = await db
        .collection(collectionName)
        .where('Timestamp', '>=', admin.firestore.Timestamp.fromDate(start))
        .where('Timestamp', '<', admin.firestore.Timestamp.fromDate(end))
        .get();

    if (snapshot.empty) {
        logger.info(`No documents to moderate for ${collectionName} on current day.`);
        return { scanned: 0, updated: 0 };
    }

    let updated = 0;
    for (const doc of snapshot.docs) {
        const payload = buildSubmissionPayloadFromDoc(doc.data());
        if (!payload.title || !payload.description) {
            continue;
        }

        const heuristic = heuristicModeration(payload);
        const aiResult = apiKey
            ? await runGeminiModeration({ apiKey, payload: { scope: 'submission', ...payload } })
            : null;

        const finalResult = mergeModeration(heuristic, aiResult);

        const updateData = {
            qualityScore: finalResult.qualityScore,
            contentStatus: finalResult.status,
            deprioritizeInFeed:
                finalResult.status === 'low_quality' || finalResult.qualityScore < 0.7,
            moderationFlags: finalResult.flags,
            moderationSource: finalResult.source,
            moderationLastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (finalResult.status === 'blocked') {
            updateData.Report = true;
        }

        await doc.ref.update(updateData);
        updated += 1;
    }

    logger.info(`Moderation completed for ${collectionName}`, {
        scanned: snapshot.size,
        updated,
    });

    return { scanned: snapshot.size, updated };
}

exports.dailyModerateCommunityContent = onSchedule(
    {
        region: 'us-central1',
        schedule: '0 2 * * *',
        timeZone: 'UTC',
        timeoutSeconds: 540,
        memory: '512MiB',
        secrets: [geminiApiKey],
    },
    async () => {
        const key = geminiApiKey.value();
        const normalizedKey = key && key.trim() ? key.trim() : '';
        if (!normalizedKey) {
            logger.warn('GEMINI_API_KEY secret is missing, scheduler will use heuristic moderation only.');
        }

        const exploreStats = await moderateCollectionForToday('Explore', normalizedKey);
        const discussionStats = await moderateCollectionForToday('Discussions', normalizedKey);

        logger.info('Daily moderation scheduler run completed.', {
            explore: exploreStats,
            discussions: discussionStats,
        });
    },
);

exports.sendFcmNotification = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        timeoutSeconds: 30,
        memory: '256MiB',
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError('unauthenticated', 'Authentication is required.');
        }
        if (request.auth.token.admin !== true) {
             throw new HttpsError('permission-denied', 'Only admins can send direct push messages.');
        }

        const title = validateText(request.data?.title, 'title', 1, 120);
        const body = validateText(request.data?.body, 'body', 1, 300);
        const token = validateText(request.data?.token, 'token', 20, 4096);

        const rawData = request.data?.data;
        const data = rawData && typeof rawData === 'object' ? rawData : {};
        const stringData = Object.fromEntries(
            Object.entries(data).map(([k, v]) => [String(k), String(v)]),
        );

        const message = {
            notification: { title, body },
            data: stringData,
            token,
        };

        try {
            const response = await admin.messaging().send(message);
            return {
                success: true,
                message: 'Notification sent successfully',
                response,
            };
        } catch (err) {
            logger.error('FCM send failed', err);
            throw new HttpsError('internal', err?.message || 'Failed to send notification');
        }
    },
);

exports.sendFcmHttp = onRequest(
    {
        region: 'us-central1',
        timeoutSeconds: 60,
        memory: '256MiB',
        cors: true,
        secrets: [internalFcmApiKey],
    },
    async (req, res) => {
        if (req.method !== 'POST') {
            return writeJson(res, 405, { success: false, message: 'Only POST is allowed' });
        }

        const expectedApiKey = (internalFcmApiKey.value() || '').trim();
        const requestApiKey = getApiKeyFromRequest(req);
        if (!expectedApiKey || requestApiKey !== expectedApiKey) {
            return writeJson(res, 401, { success: false, message: 'Unauthorized' });
        }

        try {
            const bodyData = parseRequestBody(req);
            const title = validateText(bodyData?.title, 'title', 1, 120);
            const body = validateText(bodyData?.body, 'body', 1, 300);
            const token = validateText(bodyData?.token, 'token', 20, 4096);
            const data = normalizeDataMap(bodyData?.data);
            const dryRun = bodyData?.dryRun === true;

            const response = await admin.messaging().send(
                {
                    notification: { title, body },
                    data,
                    token,
                },
                dryRun,
            );

            return writeJson(res, 200, {
                success: true,
                message: dryRun
                    ? 'Dry run successful for single notification'
                    : 'Notification sent successfully',
                response,
            });
        } catch (err) {
            logger.error('sendFcmHttp failed', err);
            return writeJson(res, 500, {
                success: false,
                message: 'Failed to send notification',
                error: err?.message || 'Unknown error',
            });
        }
    },
);

exports.sendFcmBroadcastHttp = onRequest(
    {
        region: 'us-central1',
        timeoutSeconds: 300,
        memory: '512MiB',
        cors: true,
        secrets: [internalFcmApiKey],
    },
    async (req, res) => {
        if (req.method !== 'POST') {
            return writeJson(res, 405, { success: false, message: 'Only POST is allowed' });
        }

        const expectedApiKey = (internalFcmApiKey.value() || '').trim();
        const requestApiKey = getApiKeyFromRequest(req);
        if (!expectedApiKey || requestApiKey !== expectedApiKey) {
            return writeJson(res, 401, { success: false, message: 'Unauthorized' });
        }

        try {
            const bodyData = parseRequestBody(req);
            const title = validateText(bodyData?.title, 'title', 1, 120);
            const body = validateText(bodyData?.body, 'body', 1, 300);
            const data = normalizeDataMap(bodyData?.data);
            const dryRun = bodyData?.dryRun === true;

            const providedTokens = Array.isArray(bodyData?.tokens)
                ? bodyData.tokens
                    .map((item) => String(item).trim())
                    .filter((item) => item.length >= 20)
                : [];

            const maxUsers = Number(bodyData?.maxUsers || 10000);

            let tokens = [...new Set(providedTokens)];
            let scannedUsers = 0;

            if (!tokens.length) {
                const fetched = await fetchAllUserTokens({
                    maxUsers: Number.isFinite(maxUsers) ? Math.max(1, maxUsers) : 10000,
                });
                tokens = fetched.tokens;
                scannedUsers = fetched.scannedUsers;
            }

            if (!tokens.length) {
                return writeJson(res, 200, {
                    success: true,
                    message: 'No FCM tokens found to broadcast',
                    sentCount: 0,
                    failedCount: 0,
                    scannedUsers,
                });
            }

            const result = await sendMulticastInChunks({
                tokens,
                title,
                body,
                data,
                dryRun,
            });

            return writeJson(res, 200, {
                success: result.failureCount === 0,
                message: dryRun
                    ? 'Broadcast dry run completed'
                    : 'Broadcast completed',
                totalTokens: tokens.length,
                sentCount: result.successCount,
                failedCount: result.failureCount,
                scannedUsers,
                errors: result.errors,
            });
        } catch (err) {
            logger.error('sendFcmBroadcastHttp failed', err);
            return writeJson(res, 500, {
                success: false,
                message: 'Failed to broadcast notification',
                error: err?.message || 'Unknown error',
            });
        }
    },
);

