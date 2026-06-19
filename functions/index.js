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
const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");
const legacyGeminiApiKey = defineSecret("GEMINI_API_KEY");
const OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions";
// Use the same model slug you test in Postman. Free :free models are rate-limited
// from Cloud Functions, so default to a low-cost model that works server-side.
const DEFAULT_OPENROUTER_MODEL = "meta-llama/llama-3.1-8b-instruct";
const OPENROUTER_FALLBACK_MODELS = ["google/gemini-2.5-flash"];
const FBLA_SYSTEM_PROMPT =
  "You are a helpful AI assistant for the FBLA Member App and FBLA (Future Business Leaders of America). " +
  "Help users navigate the app (Home, Events, Resources, Social/BlueWave, More), find features, " +
  "upload videos, share posts, save events, and use resources. Also help with competitions, " +
  "leadership, chapter activities, business topics, and FBLA event prep. Keep answers practical and concise. " +
  "For emphasis, wrap important words in **double asterisks** — the app renders them as bold text.";

const RUBRIC_JUDGE_SYSTEM_PROMPT =
  "You are an experienced FBLA competitive-events judge. " +
  "Score the student's performance against each rubric indicator from 1 (weak) to 5 (excellent). " +
  "Respond with ONLY valid JSON (no markdown fences) in this exact shape: " +
  '{"overallScore":3.8,"dimensions":[{"indicator":"...","score":4,"evidence":"..."}],"topFix":"one actionable fix","judgeQuestion":"one follow-up question"}' +
  ". Include one dimension object per indicator provided. overallScore is the average of dimension scores.";

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

/** Authenticated AI chat — OpenRouter API key stays in Firebase Secret Manager. */
exports.chatWithGemini = onCall(
  {
    region: "us-central1",
    secrets: [openRouterApiKey, legacyGeminiApiKey],
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

    const apiKey = resolveOpenRouterApiKey();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "OpenRouter API key is not configured. Get a key at https://openrouter.ai/keys, save to assets/gemini.txt, then run: .\\scripts\\set-gemini-secret.ps1",
      );
    }
    if (!apiKey.startsWith("sk-or")) {
      throw new HttpsError(
        "failed-precondition",
        "OpenRouter API key must start with sk-or-v1. Get one at https://openrouter.ai/keys",
      );
    }

    const rawMessages = request.data?.messages;
    if (!Array.isArray(rawMessages) || rawMessages.length === 0) {
      throw new HttpsError("invalid-argument", "messages array is required.");
    }

    const model =
      cleanText(process.env.OPENROUTER_MODEL) || DEFAULT_OPENROUTER_MODEL;
    const modelsToTry = uniqueStrings([model, ...OPENROUTER_FALLBACK_MODELS]);
    const mode = cleanText(request.data?.mode);
    const systemPrompt =
      mode === "rubric_judge" ? RUBRIC_JUDGE_SYSTEM_PROMPT : FBLA_SYSTEM_PROMPT;

    try {
      const text = await generateOpenRouterReply(
        apiKey,
        modelsToTry,
        rawMessages,
        systemPrompt,
        mode,
      );
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

function resolveOpenRouterApiKey() {
  const fromOpenRouter = cleanText(openRouterApiKey.value());
  if (fromOpenRouter) return fromOpenRouter;

  const fromLegacy = cleanText(legacyGeminiApiKey.value());
  if (fromLegacy.startsWith("sk-or")) return fromLegacy;

  return (
    cleanText(process.env.OPENROUTER_API_KEY) ||
    cleanText(process.env.GEMINI_API_KEY)
  );
}

function toOpenRouterMessages(rawMessages, systemPrompt) {
  const messages = [{ role: "system", content: systemPrompt || FBLA_SYSTEM_PROMPT }];

  for (const item of rawMessages) {
    if (!item || typeof item !== "object") continue;
    const role = cleanText(item.role).toLowerCase();
    const content = cleanText(item.content);
    if (!content) continue;

    if (role === "system") {
      messages[0].content += `\n\n${content}`;
      continue;
    }

    const openAiRole =
      role === "assistant" || role === "model" ? "assistant" : "user";
    messages.push({ role: openAiRole, content });
  }

  const system = messages[0];
  const history = messages.slice(1).slice(-20);
  return [system, ...history];
}

async function readOpenRouterError(response) {
  try {
    const data = await response.json();
    const message = cleanText(data?.error?.message);
    if (message) return message;
  } catch (_) {
    // ignore parse errors
  }
  return `HTTP ${response.status}`;
}

function friendlyOpenRouterError(status, message) {
  const lower = message.toLowerCase();
  if (
    status === 401 ||
    lower.includes("invalid api key") ||
    lower.includes("unauthorized") ||
    lower.includes("authentication")
  ) {
    return "authentication failed — check your OpenRouter key at https://openrouter.ai/keys";
  }
  if (status === 402 || lower.includes("insufficient credits")) {
    return "OpenRouter credits needed — add credits at https://openrouter.ai/settings/credits";
  }
  if (status === 429 || lower.includes("rate limit") || lower.includes("rate-limited")) {
    return message || "rate limit reached for this model";
  }
  if (lower.includes("quota")) {
    return message || "quota limit reached for this model";
  }
  return message;
}

async function generateOpenRouterReply(
  apiKey,
  modelsToTry,
  rawMessages,
  systemPrompt,
  mode,
) {
  const messages = toOpenRouterMessages(rawMessages, systemPrompt);
  const isRubric = mode === "rubric_judge";
  const errors = [];

  for (const model of modelsToTry) {
    const response = await fetch(OPENROUTER_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://fbla-2026-kushal.web.app",
        "X-Title": "FBLA Member App",
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: isRubric ? 0.3 : 0.6,
        max_tokens: isRubric ? 1200 : 768,
      }),
    });

    if (!response.ok) {
      const detail = await readOpenRouterError(response);
      const friendly = friendlyOpenRouterError(response.status, detail);
      errors.push(`${model}: ${friendly}`);
      logger.warn("OpenRouter model failed", {
        model,
        status: response.status,
        detail,
      });
      // Do not hammer fallbacks when the account/model is rate-limited.
      if (response.status === 429 || response.status === 402) {
        break;
      }
      continue;
    }

    const data = await response.json();
    const text = cleanText(data?.choices?.[0]?.message?.content);
    if (!text) {
      errors.push(`${model}: returned empty text`);
      continue;
    }

    const finishReason = data?.choices?.[0]?.finish_reason;
    if (finishReason === "length") {
      return {
        reply: `${text}\n\n(Reply truncated by token limit. Ask "continue" for the rest.)`,
        model,
      };
    }

    return { reply: text, model };
  }

  const authHit = errors.some((entry) =>
    entry.toLowerCase().includes("authentication"),
  );
  if (authHit) {
    throw new Error(
      "OpenRouter authentication failed. Put your sk-or-v1 key in assets/gemini.txt and run .\\scripts\\set-gemini-secret.ps1",
    );
  }

  const creditsHit = errors.some((entry) =>
    entry.toLowerCase().includes("credits"),
  );
  if (creditsHit) {
    throw new Error(
      "OpenRouter needs credits for this model. Add credits at https://openrouter.ai/settings/credits or set OPENROUTER_MODEL in functions/.env to a free model you use in Postman.",
    );
  }

  throw new Error(
    errors.length > 0
      ? errors[0]
      : "OpenRouter request failed. Set OPENROUTER_MODEL in functions/.env to the same model slug you use in Postman, then redeploy.",
  );
}
