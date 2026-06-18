# Discord Bot Sync

The Flutter app queues posts in Firestore; Cloud Functions deliver them to your
Discord server using the bot token (never stored in the app).

## Deploy (Blaze plan required)

```bash
# 1. Bot token (secret)
firebase functions:secrets:set DISCORD_BOT_TOKEN

# 2. Channel IDs — create functions/.env
#    DISCORD_ANNOUNCEMENTS_CHANNEL_ID=...
#    DISCORD_GENERAL_CHANNEL_ID=...
#    DISCORD_EVENTS_CHANNEL_ID=...

cd functions
npm install
cd ..
firebase deploy --only functions,firestore:rules
```

## Firestore config (optional)

The app falls back to bundled defaults in `lib/constants/discord_defaults.dart`.
To also store config in Firestore (recommended), either:

**A. Firebase Console** — create `discord_config/default` (see JSON below).

**B. After deploying functions**, call the setup endpoint once:

```bash
curl https://us-central1-fbla-2026-kushal.cloudfunctions.net/setupDiscordConfig
```

**C. Local seed script** (requires `gcloud auth application-default login`):

```bash
cd functions && node scripts/seed-discord-config.js
```

```json
{
  "inviteUrl": "https://discord.gg/your-invite",
  "guildName": "FBLA Chapter Server",
  "botEnabled": true,
  "channels": {
    "announcements": "CHANNEL_ID",
    "general": "CHANNEL_ID",
    "events": "CHANNEL_ID"
  }
}
```

## App features (Social → Discord Hub)

| Action | Discord channel |
|--------|-----------------|
| Latest Announcement | `#announcements` (@here on major news) |
| Next Upcoming Event | `#events` |
| BlueWave Highlight | `#general` |
| Custom Update | User picks channel |

**Recent Bot Activity** shows live queue status: Queued → Posted / Failed.

## Queue document shape

```json
{
  "title": "Chapter Meeting Friday",
  "body": "Join us at 3 PM for competition prep.",
  "channel": "announcements",
  "type": "announcement",
  "status": "pending",
  "authorName": "Member Name",
  "createdBy": "firebase_uid"
}
```

Supported `type` values: `announcement`, `general_update`, `event`, `bluewave`, `forum`.

The function sets `status` to `sent` or `failed` with `discordMessageId` on success.
