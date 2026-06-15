# Discord Bot Sync

The Flutter app writes pending posts to the `discord_outbox` Firestore collection.
This Firebase Function watches new documents and posts them to Discord using the
bot token on the server side.

## Required Firebase Cloud Setup

Firebase Functions must be enabled for the project. Deploying Cloud Functions
usually requires the Firebase Blaze plan because the function makes an outgoing
network request to Discord.

Set the bot token as a Firebase secret:

```bash
firebase functions:secrets:set DISCORD_BOT_TOKEN
```

Create `functions/.env` locally for non-secret IDs:

```env
DISCORD_ANNOUNCEMENTS_CHANNEL_ID=your_announcements_channel_id
DISCORD_GENERAL_CHANNEL_ID=your_general_channel_id
DISCORD_GUILD_ID=your_server_id
```

The function also loads the repository root `.env` during local development, so
the IDs you already saved there will work with the emulator.

## Install And Deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Firestore Queue Shape

The app creates documents like this:

```json
{
  "title": "Chapter Meeting Friday",
  "body": "Join us at 3 PM for competition prep.",
  "channel": "announcements",
  "type": "announcement",
  "status": "pending"
}
```

The function updates `status` to `sent` after Discord accepts the message, or
`failed` with an `error` if the Discord API call fails.
