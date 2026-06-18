/**
 * One-time seed for discord_config/default in Firestore.
 * Run: node scripts/seed-discord-config.js
 * Requires: firebase login + gcloud auth application-default login
 *   OR run from a machine with Firebase Admin access.
 */
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

const admin = require("firebase-admin");

const projectId = process.env.GCLOUD_PROJECT || "fbla-2026-kushal";

admin.initializeApp({ projectId });

const config = {
  inviteUrl: process.env.DISCORD_INVITE_URL || "",
  guildName: "FBLA Chapter Server",
  botEnabled: true,
  channels: {
    announcements: process.env.DISCORD_ANNOUNCEMENTS_CHANNEL_ID || "",
    general: process.env.DISCORD_GENERAL_CHANNEL_ID || "",
    events: process.env.DISCORD_EVENTS_CHANNEL_ID || "",
  },
};

async function main() {
  await admin
    .firestore()
    .collection("discord_config")
    .doc("default")
    .set(config, { merge: true });

  console.log("discord_config/default written:");
  console.log(JSON.stringify(config, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Failed to seed discord_config:", err.message);
    process.exit(1);
  });
