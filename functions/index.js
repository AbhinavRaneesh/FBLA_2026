const path = require("path");

require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });
require("dotenv").config();

const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const discordBotToken = defineSecret("DISCORD_BOT_TOKEN");

const CHANNEL_ENV_BY_NAME = {
  announcements: "DISCORD_ANNOUNCEMENTS_CHANNEL_ID",
  general: "DISCORD_GENERAL_CHANNEL_ID",
};

exports.postDiscordOutboxMessage = onDocumentCreated(
  {
    document: "discord_outbox/{messageId}",
    region: "us-central1",
    secrets: [discordBotToken],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageId = event.params.messageId;
    const data = snapshot.data() || {};

    if ((data.status || "pending") !== "pending") {
      logger.info("Skipping non-pending Discord outbox item", { messageId });
      return;
    }

    const token = discordBotToken.value() || process.env.DISCORD_BOT_TOKEN;
    const channelName = normalizeChannel(data.channel);
    const channelId = resolveChannelId(channelName);
    const title = cleanText(data.title);
    const body = cleanText(data.body);

    if (!token || !channelId || !title || !body) {
      await markFailed(snapshot.ref, {
        error:
          "Missing Discord token, channel ID, title, or message body. Check Firebase secrets/env.",
      });
      return;
    }

    const embed = buildDiscordEmbed({
      title,
      body,
      type: cleanText(data.type) || "announcement",
      authorName: cleanText(data.authorName),
      sourceId: cleanText(data.sourceId),
    });

    try {
      const response = await fetch(
        `https://discord.com/api/v10/channels/${channelId}/messages`,
        {
          method: "POST",
          headers: {
            Authorization: `Bot ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            content: channelName === "announcements" ? "@here" : undefined,
            embeds: [embed],
            allowed_mentions: channelName === "announcements"
              ? { parse: ["everyone"] }
              : { parse: [] },
          }),
        },
      );

      const responseBody = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(
          `Discord API ${response.status}: ${JSON.stringify(responseBody)}`,
        );
      }

      await snapshot.ref.set(
        {
          status: "sent",
          discordMessageId: responseBody.id || null,
          discordChannelId: channelId,
          postedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      logger.info("Discord message posted", {
        messageId,
        discordMessageId: responseBody.id,
        channelName,
      });
    } catch (error) {
      logger.error("Discord post failed", { messageId, error });
      await markFailed(snapshot.ref, { error: error.message || String(error) });
    }
  },
);

function resolveChannelId(channelName) {
  const envKey = CHANNEL_ENV_BY_NAME[channelName] || CHANNEL_ENV_BY_NAME.general;
  return process.env[envKey] || "";
}

function normalizeChannel(value) {
  const channel = cleanText(value).toLowerCase();
  return CHANNEL_ENV_BY_NAME[channel] ? channel : "general";
}

function cleanText(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildDiscordEmbed({ title, body, type, authorName, sourceId }) {
  const fields = [];
  if (authorName) {
    fields.push({ name: "Queued by", value: authorName, inline: true });
  }
  if (sourceId) {
    fields.push({ name: "App Source", value: sourceId, inline: true });
  }

  return {
    title,
    description: body.slice(0, 4000),
    color: type === "announcement" ? 0xfdb913 : 0x5865f2,
    fields,
    footer: { text: "FBLA Member App" },
    timestamp: new Date().toISOString(),
  };
}

async function markFailed(ref, { error }) {
  await ref.set(
    {
      status: "failed",
      error,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}
