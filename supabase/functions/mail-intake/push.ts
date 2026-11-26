// Push notifications through the Apple Push Notification service (APNs).
//
// Secrets (Supabase Edge Function secrets, never in the repository):
//   APNS_KEY_P8   content of the .p8 key file from the Apple developer account
//   APNS_KEY_ID   key id of that key
//   APNS_TEAM_ID  team id of the Apple developer account
// The topic is the bundle id of the app. TestFlight builds use the production server.

import type { Suggestion } from "./analyze.ts";

export interface PushMessage {
  title: string;
  body: string;
}

/** Sends one message to all tokens and returns the tokens that Apple no longer accepts. */
export type PushSender = (tokens: string[], message: PushMessage) => Promise<{ invalid: string[] }>;

const PLAYFUL_EVENT_TITLES = [
  "📅 Ein Termin ist im Anflug",
  "🗓️ Die Mails haben was ausgebrütet",
  "📬 Psst, da will jemand in den Kalender",
];
const PLAYFUL_TASK_TITLES = [
  "📝 Neue Aufgabe im Anflug",
  "🎒 Da muss jemand an etwas denken (nicht ihr!)",
  "🧠 Mental Load abgenommen: Vorschlag wartet",
];
const PLAYFUL_MANY_TITLES = [
  "🐣 Frisch geschlüpft: neue Vorschläge",
  "📬 Die Post hat geliefert",
];

function pick<T>(list: T[], random: () => number): T {
  return list[Math.floor(random() * list.length) % list.length];
}

/** A playful message for the new suggestions. Only suggestions with something to do are passed in. */
export function buildPushMessage(suggestions: Suggestion[], random: () => number = Math.random): PushMessage {
  if (suggestions.length === 1) {
    const [one] = suggestions;
    const title = pick(one.kind === "event" ? PLAYFUL_EVENT_TITLES : PLAYFUL_TASK_TITLES, random);
    return { title, body: `${one.title}. Antippen, ansehen, übernehmen oder wegwischen.` };
  }
  return {
    title: pick(PLAYFUL_MANY_TITLES, random),
    body: `${suggestions.length} neue Vorschläge warten auf euch. Kurz in die Glocke schauen!`,
  };
}

function base64Url(bytes: Uint8Array): string {
  let text = "";
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array {
  const base64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
}

/** The JWT that identifies this server to APNs (ES256, valid up to one hour). */
export async function createApnsJwt(keyPem: string, keyId: string, teamId: string, nowSeconds: number): Promise<string> {
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = base64Url(encoder.encode(JSON.stringify({ iss: teamId, iat: nowSeconds })));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(keyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  // WebCrypto returns the raw r||s signature that JWT expects.
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(`${header}.${claims}`)),
  );
  return `${header}.${claims}.${base64Url(signature)}`;
}

export interface ApnsConfig {
  keyPem: string;
  keyId: string;
  teamId: string;
  topic: string;
  host?: string;
}

/** Reasons after which a token is dead and should be deleted. */
const DEAD_REASONS = new Set(["BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"]);

export function createApnsSender(
  config: ApnsConfig | null,
  fetchImpl: typeof fetch = fetch,
  now: () => number = () => Math.floor(Date.now() / 1000),
): PushSender {
  let cached: { jwt: string; issuedAt: number } | null = null;
  return async (tokens, message) => {
    if (!config || tokens.length === 0) return { invalid: [] };
    const nowSeconds = now();
    // Apple asks for a new token at most every 20 minutes and at least once per hour.
    if (!cached || nowSeconds - cached.issuedAt > 40 * 60) {
      cached = { jwt: await createApnsJwt(config.keyPem, config.keyId, config.teamId, nowSeconds), issuedAt: nowSeconds };
    }
    const host = config.host ?? "https://api.push.apple.com";
    const body = JSON.stringify({
      aps: { alert: { title: message.title, body: message.body }, sound: "default" },
    });
    const invalid: string[] = [];
    for (const token of tokens) {
      try {
        const response = await fetchImpl(`${host}/3/device/${token}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${cached.jwt}`,
            "apns-topic": config.topic,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "content-type": "application/json",
          },
          body,
          signal: AbortSignal.timeout(10_000),
        });
        if (!response.ok) {
          let reason = "";
          try {
            reason = String((await response.json())?.reason ?? "");
          } catch { /* no body */ }
          if (response.status === 410 || DEAD_REASONS.has(reason)) invalid.push(token);
          else console.error(`push failed: status=${response.status} reason=${reason}`);
        }
      } catch (error) {
        console.error("push failed", error instanceof Error ? error.message : "unknown error");
      }
    }
    return { invalid };
  };
}
