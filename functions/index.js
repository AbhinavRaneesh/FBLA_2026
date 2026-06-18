const fs = require("fs");
const path = require("path");

// Load functions/.env only (quiet). Avoid dotenvx v17 — it can hang Firebase deploy discovery.
const localEnvPath = path.join(__dirname, ".env");
if (fs.existsSync(localEnvPath)) {
  require("dotenv").config({ path: localEnvPath });
}

const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { defineSecret } = require("firebase-functions/params");

function getDb() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  return admin.firestore();
}

const discordBotToken = defineSecret("DISCORD_BOT_TOKEN");
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const DEFAULT_GEMINI_MODELS = [
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.0-flash",
];
const FBLA_SYSTEM_PROMPT =
  "You are a helpful AI assistant for the FBLA Member App and FBLA (Future Business Leaders of America). " +
  "Help users navigate the app (Home, Events, Resources, Social/BlueWave, More), find features, " +
  "upload videos, share posts, save events, and use resources. Also help with competitions, " +
  "leadership, chapter activities, business topics, and FBLA event prep. Keep answers practical and concise.";

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

/** Authenticated AI chat — Gemini API key stays in Firebase Secret Manager. */
exports.chatWithGemini = onCall(
  {
    region: "us-central1",
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to use the AI assistant.",
      );
    }

    const apiKey = cleanText(geminiApiKey.value());
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "Gemini API key is not configured. Run: .\\scripts\\set-gemini-secret.ps1",
      );
    }

    const rawMessages = request.data?.messages;
    if (!Array.isArray(rawMessages) || rawMessages.length === 0) {
      throw new HttpsError("invalid-argument", "messages array is required.");
    }

    const model =
      cleanText(process.env.GEMINI_MODEL) || DEFAULT_GEMINI_MODELS[0];
    const modelsToTry = uniqueStrings([model, ...DEFAULT_GEMINI_MODELS]);

    try {
      const text = await generateGeminiReply(apiKey, modelsToTry, rawMessages);
      logger.info("chatWithGemini success", {
        uid: request.auth.uid,
        model: text.model,
        messageCount: rawMessages.length,
      });
      return { text: text.reply };
    } catch (error) {
      logger.error("chatWithGemini failed", {
        uid: request.auth.uid,
        error: error.message || String(error),
      });
      throw new HttpsError(
        "internal",
        error.message || "AI assistant request failed.",
      );
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

      await getDb()
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
    const configSnap = await getDb().collection("discord_config").doc("default").get();
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

function uniqueStrings(values) {
  const seen = new Set();
  const result = [];
  for (const value of values) {
    const trimmed = cleanText(value);
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    result.push(trimmed);
  }
  return result;
}

function toGeminiRequest(rawMessages) {
  let systemText = FBLA_SYSTEM_PROMPT;
  const turns = [];

  for (const item of rawMessages) {
    if (!item || typeof item !== "object") continue;
    const role = cleanText(item.role).toLowerCase();
    const content = cleanText(item.content);
    if (!content) continue;

    if (role === "system") {
      systemText = `${systemText}\n\n${content}`;
      continue;
    }

    const geminiRole =
      role === "assistant" || role === "model" ? "model" : "user";
    turns.push({ role: geminiRole, text: content });
  }

  const contents = normalizeGeminiTurns(turns).slice(-20);
  if (contents.length === 0) {
    contents.push({
      role: "user",
      parts: [{ text: "Hello" }],
    });
  }

  return {
    systemInstruction: {
      parts: [{ text: systemText }],
    },
    contents,
    generationConfig: {
      temperature: 0.6,
      maxOutputTokens: 768,
    },
  };
}

function normalizeGeminiTurns(turns) {
  const merged = [];

  for (const turn of turns) {
    const last = merged[merged.length - 1];
    if (last && last.role === turn.role) {
      last.parts[0].text += `\n\n${turn.text}`;
      continue;
    }

    merged.push({
      role: turn.role,
      parts: [{ text: turn.text }],
    });
  }

  while (merged.length > 0 && merged[0].role !== "user") {
    merged.shift();
  }
  while (merged.length > 0 && merged[merged.length - 1].role !== "user") {
    merged.pop();
  }

  return merged;
}

async function readGeminiError(response) {
  try {
    const data = await response.json();
    const message = cleanText(data?.error?.message);
    if (message) return message;
  } catch (_) {
    // ignore parse errors
  }
  return `HTTP ${response.status}`;
}

function buildGeminiHeaders(apiKey) {
  const headers = { "Content-Type": "application/json" };
  const token = cleanText(apiKey);
  // AI Studio access tokens (Postman: Authorization Bearer) vs API keys (x-goog-api-key).
  if (token.startsWith("AQ.") || token.startsWith("ya29.")) {
    headers.Authorization = `Bearer ${token}`;
  } else {
    headers["x-goog-api-key"] = token;
  }
  return headers;
}

function friendlyGeminiError(status, message) {
  const lower = message.toLowerCase();
  if (
    lower.includes("api key not found") ||
    lower.includes("api key invalid") ||
    lower.includes("invalid api key")
  ) {
    return "invalid API key — create a new key at https://aistudio.google.com/apikey and run: firebase functions:secrets:set GEMINI_API_KEY";
  }
  if (status === 429 || lower.includes("quota") || lower.includes("rate limit")) {
    return "quota limit reached";
  }
  return message;
}

async function generateGeminiReply(apiKey, modelsToTry, rawMessages) {
  const requestBody = toGeminiRequest(rawMessages);
  const errors = [];

  for (const model of modelsToTry) {
    const endpoint =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

    const response = await fetch(endpoint, {
      method: "POST",
      headers: buildGeminiHeaders(apiKey),
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const detail = await readGeminiError(response);
      const friendly = friendlyGeminiError(response.status, detail);
      errors.push(`${model}: ${friendly}`);
      logger.warn("Gemini model failed", {
        model,
        status: response.status,
        detail,
      });
      continue;
    }

    const data = await response.json();
    const candidates = data.candidates;
    if (!Array.isArray(candidates) || candidates.length === 0) {
      errors.push(`${model}: returned no candidates`);
      continue;
    }

    const firstCandidate = candidates[0] || {};
    const parts = firstCandidate.content?.parts;
    if (!Array.isArray(parts)) {
      errors.push(`${model}: returned no content parts`);
      continue;
    }

    const combined = parts
      .map((part) => (part && typeof part.text === "string" ? part.text.trim() : ""))
      .filter(Boolean)
      .join("\n")
      .trim();

    if (!combined) {
      errors.push(`${model}: returned empty text`);
      continue;
    }

    if (firstCandidate.finishReason === "MAX_TOKENS") {
      return {
        reply: `${combined}\n\n(Reply truncated by token limit. Ask "continue" for the rest.)`,
        model,
      };
    }

    return { reply: combined, model };
  }

  const quotaHit = errors.some((entry) => entry.includes("quota"));
  if (quotaHit) {
    throw new Error(
      "The AI is temporarily busy (API quota limit). Wait a minute and try again.",
    );
  }

  throw new Error(
    errors.length > 0 ? errors[errors.length - 1] : "Gemini request failed.",
  );
}
