const path = require("path");

require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });
require("dotenv").config();

const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const db = admin.firestore();
const discordBotToken = defineSecret("DISCORD_BOT_TOKEN");

const CHANNEL_ENV_BY_NAME = {
  announcements: "DISCORD_ANNOUNCEMENTS_CHANNEL_ID",
  general: "DISCORD_GENERAL_CHANNEL_ID",
  events: "DISCORD_EVENTS_CHANNEL_ID",
};

const TYPE_COLORS = {
  announcement: 0xfdb913,
  general_update: 0x5865f2,
  event: 0x00274d,
  bluewave: 0x0ea5e9,
  forum: 0x57f287,
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
    const channelId = await resolveChannelId(channelName);
    const title = cleanText(data.title);
    const body = cleanText(data.body);
    const type = cleanText(data.type) || "general_update";

    if (!token || !channelId || !title || !body) {
      await markFailed(snapshot.ref, {
        error:
          "Missing Discord token, channel ID, title, or message body. Set Firebase secrets and channel IDs.",
      });
      return;
    }

    const embed = buildDiscordEmbed({
      title,
      body,
      type,
      authorName: cleanText(data.authorName),
      sourceId: cleanText(data.sourceId),
      imageUrl: cleanText(data.imageUrl),
      actionUrl: cleanText(data.actionUrl),
      actionLabel: cleanText(data.actionLabel) || "Open in FBLA App",
    });

    const pingEveryone = channelName === "announcements" && type === "announcement";

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
            content: pingEveryone ? "@here" : undefined,
            embeds: [embed],
            allowed_mentions: pingEveryone
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
        type,
      });
    } catch (error) {
      logger.error("Discord post failed", { messageId, error });
      await markFailed(snapshot.ref, { error: error.message || String(error) });
    }
  },
);

/** One-time/idempotent setup: writes discord_config/default from env vars. */
exports.setupDiscordConfig = onRequest(
  { region: "us-central1", invoker: "public" },
  async (_req, res) => {
    try {
      const config = buildDiscordConfigFromEnv();
      if (!config.inviteUrl && !config.channels.announcements) {
        res.status(400).json({
          error:
            "No Discord env vars found. Set DISCORD_INVITE_URL and channel IDs in functions/.env and redeploy.",
        });
        return;
      }

      await db
        .collection("discord_config")
        .doc("default")
        .set(config, { merge: true });

      logger.info("discord_config/default seeded", { guildName: config.guildName });
      res.status(200).json({ ok: true, config });
    } catch (error) {
      logger.error("setupDiscordConfig failed", { error });
      res.status(500).json({ error: error.message || String(error) });
    }
  },
);

function buildDiscordConfigFromEnv() {
  return {
    inviteUrl: process.env.DISCORD_INVITE_URL || "",
    guildName: process.env.DISCORD_GUILD_NAME || "FBLA Chapter Server",
    botEnabled: true,
    channels: {
      announcements: process.env.DISCORD_ANNOUNCEMENTS_CHANNEL_ID || "",
      general: process.env.DISCORD_GENERAL_CHANNEL_ID || "",
      events: process.env.DISCORD_EVENTS_CHANNEL_ID || "",
    },
  };
}

async function resolveChannelId(channelName) {
  const envKey = CHANNEL_ENV_BY_NAME[channelName] || CHANNEL_ENV_BY_NAME.general;
  const fromEnv = process.env[envKey] || "";
  if (fromEnv) return fromEnv;

  try {
    const configSnap = await db.collection("discord_config").doc("default").get();
    const channels = configSnap.data()?.channels || {};
    const fromConfig = cleanText(channels[channelName]);
    if (fromConfig) return fromConfig;
  } catch (error) {
    logger.warn("Could not read discord_config for channel IDs", { error });
  }

  return "";
}

function normalizeChannel(value) {
  const channel = cleanText(value).toLowerCase();
  return CHANNEL_ENV_BY_NAME[channel] ? channel : "general";
}

function cleanText(value) {
  return typeof value === "string" ? value.trim() : "";
}

/** Discord embeds only accept public http(s) URLs — not assets or local paths. */
function isValidDiscordUrl(value) {
  const url = cleanText(value);
  if (!url) return false;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return false;
    }
    return parsed.hostname.length > 0;
  } catch (_) {
    return false;
  }
}

function buildDiscordEmbed({
  title,
  body,
  type,
  authorName,
  sourceId,
  imageUrl,
  actionUrl,
  actionLabel,
}) {
  const fields = [];
  if (authorName) {
    fields.push({ name: "Queued by", value: authorName, inline: true });
  }
  if (sourceId) {
    fields.push({ name: "App Source", value: sourceId, inline: true });
  }

  const typeLabel = type.replace(/_/g, " ");
  fields.push({
    name: "Type",
    value: typeLabel.charAt(0).toUpperCase() + typeLabel.slice(1),
    inline: true,
  });

  const embed = {
    title,
    description: body.slice(0, 4000),
    color: TYPE_COLORS[type] || TYPE_COLORS.general_update,
    fields,
    footer: { text: "FBLA Member App · Discord Bot Sync" },
    timestamp: new Date().toISOString(),
  };

  if (isValidDiscordUrl(imageUrl)) {
    embed.image = { url: imageUrl.trim() };
  }

  if (isValidDiscordUrl(actionUrl)) {
    embed.url = actionUrl.trim();
  }

  return embed;
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
