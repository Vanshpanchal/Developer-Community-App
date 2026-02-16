# Privacy Policy Updates - February 16, 2026

## Summary of Changes

The privacy policy has been **completely revised** to accurately reflect only the actual functionality of the Developer Community App, removing any references to features that don't exist.

---

## ✅ What Was Improved

### 1. **Accurate Feature Description**

**Before:** Generic mentions of "chat messages" and "communication"  
**After:** Clear distinction between:

- Public discussions and posts (stored in cloud)
- AI chatbot conversations (stored locally on device only)
- NO user-to-user direct messaging

### 2. **Data Structure Transparency**

**Added New Section 7:** "Data Structure Transparency"

- Lists exact Firestore collection structure
- Shows all data fields stored (Username, Email, XP, Saved, etc.)
- Specifies what's public vs. private
- Documents local-only storage (Hive, Secure Storage)

### 3. **Third-Party Services Clarification**

**Removed:** References to ChatGPT/OpenAI  
**Kept:** Only Google Gemini (actual AI service used)  
**Added:** Cloudinary (image hosting), GitHub API (public data only)

### 4. **What We DON'T Do Section**

**Added explicit list:**

- ❌ No push notifications
- ❌ No user-to-user messaging
- ❌ No selling data to third parties
- ❌ No storing raw API keys on servers

### 5. **Privacy Principles Highlighted**

**Added upfront summary:**

- Email never shown to users
- Chatbot conversations never uploaded
- API keys stay on device
- AES-256 encryption everywhere
- TLS 1.2+ for all network traffic

### 6. **Detailed Data Retention Policy**

**Before:** Generic "we delete your data"  
**After:** Specific breakdown:

- What gets deleted (profile, email, private data)
- What stays (public posts/discussions show "[Deleted User]")
- How to delete local data (uninstall or clear app data)

### 7. **User Rights Enhanced**

**Added specifics:**

- How to request data export (JSON format)
- How to change/delete API keys
- Contact email for data requests
- 30-day response time commitment

---

## 📊 Data Collections Documented

### User Collection

```
Username, Email, Uid, profilePicture, XP, Saved[], SavedDiscussion[],
createdAt, bio (optional), github (optional), profileDominantColor (optional),
geminiKeyHash (optional), geminiKeySetAt (optional)
```

### Discussions Collection

```
Title, Description, Uid, Tags[], docId, Timestamp, Report,
hasPoll, poll{}, Replies (subcollection)
```

### Explore Collection

```
Title, Description, code, Uid, Tags[], docId, likes[],
likescount, Timestamp, Report
```

### Replies Subcollection

```
username, profilePicture, reply, timestamp, uid
```

---

## 🔒 Security Details Updated

### Encryption Layers:

1. **Transit:** TLS 1.2+ for all network traffic
2. **At Rest (Cloud):** AES-256 encryption via Firebase
3. **At Rest (Local):** AES-256 encryption via Hive
4. **Secure Storage:** iOS Keychain / Android EncryptedSharedPreferences

### API Key Protection:

- Raw key: Stored only in device secure storage
- Cloud storage: Only SHA-256 hash for verification
- Never transmitted unencrypted

---

## 🎯 Key Accuracy Improvements

| Previous Statement          | Updated Statement                                    |
| --------------------------- | ---------------------------------------------------- |
| "Chat messages"             | "AI chatbot conversations (local only)"              |
| "ChatGPT and Google Gemini" | "Google Gemini only"                                 |
| "Send notifications"        | "We do NOT send push notifications"                  |
| "Direct messaging"          | "Public discussions only, no user-to-user messaging" |
| Generic data fields         | Exact Firestore schema documented                    |
| "bcrypt password hashing"   | "Firebase Authentication (managed by Google)"        |

---

## 🌐 GitHub Pages Deployment

**Location:** `docs/index.html`

**To publish:**

```bash
# 1. Commit changes
git add docs/index.html
git commit -m "Update privacy policy to match actual app functionality"

# 2. Push to GitHub
git push origin main

# 3. Enable GitHub Pages in repository settings:
#    Settings → Pages → Source: main branch, /docs folder
```

**URL will be:** https://[your-username].github.io/Developer-Community-App/

---

## ✨ Contact Information

**Privacy Inquiries:** vansh.panchal7@proton.me  
**Response Time:** Within 30 days  
**Data Requests:** Include registered email and request type (access/correction/deletion)

---

## 📝 Legal Compliance

The updated privacy policy now:

- ✅ Accurately describes data collection (GDPR/CCPA compliant)
- ✅ Specifies data retention periods
- ✅ Lists all third-party processors
- ✅ Provides data structure transparency
- ✅ Documents encryption methods
- ✅ Explains user rights clearly

---

**Last Updated:** February 16, 2026  
**Document Version:** 2.0 (Complete Rewrite)
