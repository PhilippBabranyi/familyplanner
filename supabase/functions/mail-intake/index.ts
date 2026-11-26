// Edge Function `mail-intake`.
//
// Receives metadata of mails from the small script in a family member's Google account
// (integrations/gmail-apps-script). The request is authenticated with a secret token per mailbox;
// only the SHA-256 hash of the token is stored in the database.
//
// Deploy with "Verify JWT" switched OFF (the script is not a Supabase user); the token is the credential.
// The function uses the service role key that Supabase provides to every Edge Function at runtime.
// Nothing secret is stored in this file.
//
// For every new mail the function asks an AI model (analyze.ts) for a suggestion (event or task). The mail
// text is only passed to the model; the database stores the suggestion, sender, subject and a link.
// The key for the model is the Supabase secret ANTHROPIC_API_KEY.

import { type Analyzer, createAnthropicAnalyzer, type Suggestion } from "./analyze.ts";
import { type ApnsConfig, buildPushMessage, createApnsSender, type PushSender } from "./push.ts";

export interface IntakeItem {
  gmailMessageId: string;
  gmailThreadId: string;
  sender: string;
  subject: string;
  receivedAt: string;
  link: string;
  /** Mail text for the analysis only. Never stored. */
  body: string;
}

export interface Mailbox {
  id: string;
  familyId: string;
}

export interface Filters {
  senders: string[];
  keywords: string[];
}

/** Everything the handler needs from the database. Replaced by a fake in the tests. */
export interface Store {
  findMailboxByHash(hash: string): Promise<Mailbox | null>;
  touch(mailboxId: string): Promise<void>;
  loadFilters(mailboxId: string): Promise<Filters>;
  /** Returns the ids of the given Gmail messages that are already saved for this mailbox. */
  knownMessageIds(mailboxId: string, ids: string[]): Promise<Set<string>>;
  loadContext(familyId: string): Promise<string>;
  saveItems(mailbox: Mailbox, items: AnalyzedItem[]): Promise<number>;
  /** Push tokens of the family's phones. */
  loadDeviceTokens(familyId: string): Promise<string[]>;
  deleteDeviceTokens(tokens: string[]): Promise<void>;
}

export interface AnalyzedItem {
  item: IntakeItem;
  suggestion: Suggestion;
}

export interface Dependencies {
  store: Store;
  analyze: Analyzer;
  push: PushSender;
  /** Today in Europe/Berlin as YYYY-MM-DD. */
  today: () => string;
}

export const MAX_BODY_BYTES = 512 * 1024;
/** Small on purpose: every item is one model call and the function has a time limit. */
export const MAX_ITEMS = 10;
export const MAX_MAIL_CHARS = 8000;
const ANALYSIS_CONCURRENCY = 5;

export async function hashToken(token: string): Promise<string> {
  const bytes = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

const ID_PATTERN = /^[A-Za-z0-9_-]{1,100}$/;

/** Returns the cleaned items, or null if anything is malformed. */
export function validateItems(raw: unknown): IntakeItem[] | null {
  if (!Array.isArray(raw) || raw.length > MAX_ITEMS) return null;
  const items: IntakeItem[] = [];
  for (const entry of raw) {
    if (typeof entry !== "object" || entry === null) return null;
    const e = entry as Record<string, unknown>;
    if (typeof e.gmailMessageId !== "string" || !ID_PATTERN.test(e.gmailMessageId)) return null;
    if (typeof e.gmailThreadId !== "string" || !ID_PATTERN.test(e.gmailThreadId)) return null;
    if (typeof e.sender !== "string" || typeof e.subject !== "string") return null;
    if (typeof e.receivedAt !== "string" || Number.isNaN(Date.parse(e.receivedAt))) return null;
    if (typeof e.link !== "string" || !e.link.startsWith("https://mail.google.com/") || e.link.length > 500) {
      return null;
    }
    items.push({
      gmailMessageId: e.gmailMessageId,
      gmailThreadId: e.gmailThreadId,
      sender: e.sender.slice(0, 300),
      subject: e.subject.slice(0, 500),
      receivedAt: new Date(e.receivedAt).toISOString(),
      link: e.link,
      body: typeof e.body === "string" ? e.body.slice(0, MAX_MAIL_CHARS) : "",
    });
  }
  return items;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** Runs `work` over the list with at most `limit` calls at the same time, keeping the order. */
async function mapLimited<T, R>(list: T[], limit: number, work: (entry: T) => Promise<R>): Promise<R[]> {
  const results: R[] = new Array(list.length);
  let next = 0;
  const runners = Array.from({ length: Math.min(limit, list.length) }, async () => {
    while (next < list.length) {
      const index = next++;
      results[index] = await work(list[index]);
    }
  });
  await Promise.all(runners);
  return results;
}

/** Tells the family's phones about new suggestions. A failing push never fails the intake. */
async function notifyFamily(familyId: string, done: AnalyzedItem[], deps: Dependencies): Promise<void> {
  try {
    const worthIt = done.map((entry) => entry.suggestion).filter((s) => s.kind !== "none");
    if (worthIt.length === 0) return;
    const tokens = await deps.store.loadDeviceTokens(familyId);
    if (tokens.length === 0) return;
    const { invalid } = await deps.push(tokens, buildPushMessage(worthIt));
    if (invalid.length > 0) await deps.store.deleteDeviceTokens(invalid);
  } catch (error) {
    console.error("notify failed", error instanceof Error ? error.message : "unknown error");
  }
}

export async function handleRequest(req: Request, deps: Dependencies): Promise<Response> {
  const { store, analyze } = deps;
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const token = req.headers.get("x-mailbox-token");
  if (!token || token.length < 20 || token.length > 200) return json({ error: "unauthorized" }, 401);

  const text = await req.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) return json({ error: "too large" }, 413);

  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(text);
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error("not an object");
    body = parsed;
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  try {
    const mailbox = await store.findMailboxByHash(await hashToken(token));
    if (!mailbox) return json({ error: "unauthorized" }, 401);
    await store.touch(mailbox.id);

    if (body.action === "filters") {
      return json(await store.loadFilters(mailbox.id));
    }
    if (body.action === "items") {
      const items = validateItems(body.items);
      if (!items) return json({ error: "invalid items" }, 400);
      if (items.length === 0) return json({ saved: 0, handled: [] });

      // Mails that are already saved are not analyzed again, but are reported as handled.
      const known = await store.knownMessageIds(mailbox.id, items.map((i) => i.gmailMessageId));
      const fresh = items.filter((i) => !known.has(i.gmailMessageId));
      const context = fresh.length > 0 ? await store.loadContext(mailbox.familyId) : "";
      const today = deps.today();

      // A failed analysis (API down, quota) leaves the mail out, so the script sends it again next time.
      const analyzed = await mapLimited(fresh, ANALYSIS_CONCURRENCY, async (item): Promise<AnalyzedItem | null> => {
        try {
          const suggestion = await analyze({
            sender: item.sender,
            subject: item.subject,
            receivedAt: item.receivedAt,
            body: item.body,
            context,
            today,
          });
          // The text has served its purpose; it must not travel any further.
          return { item: { ...item, body: "" }, suggestion };
        } catch (error) {
          console.error("analysis failed", error instanceof Error ? error.message : "unknown error");
          return null;
        }
      });
      const done = analyzed.filter((entry): entry is AnalyzedItem => entry !== null);
      const saved = done.length === 0 ? 0 : await store.saveItems(mailbox, done);
      const handled = [...known, ...done.map((entry) => entry.item.gmailMessageId)];
      if (saved > 0) await notifyFamily(mailbox.familyId, done, deps);
      return json({ saved, handled });
    }
    return json({ error: "unknown action" }, 400);
  } catch (error) {
    console.error("mail-intake failed", error instanceof Error ? error.message : "unknown error");
    return json({ error: "server error" }, 500);
  }
}

async function createStore(): Promise<Store> {
  const { createClient } = await import("jsr:@supabase/supabase-js@2");
  const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  return {
    async findMailboxByHash(hash) {
      const { data, error } = await client.from("mailboxes").select("id,family_id").eq("token_hash", hash)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? { id: data.id, familyId: data.family_id } : null;
    },
    async touch(mailboxId) {
      const { error } = await client.from("mailboxes").update({ last_seen_at: new Date().toISOString() })
        .eq("id", mailboxId);
      if (error) throw new Error(error.message);
    },
    async loadFilters(mailboxId) {
      const { data, error } = await client.from("mail_filters").select("kind,value").eq("mailbox_id", mailboxId);
      if (error) throw new Error(error.message);
      const rows = data ?? [];
      return {
        senders: rows.filter((r) => r.kind === "sender").map((r) => r.value),
        keywords: rows.filter((r) => r.kind === "keyword").map((r) => r.value),
      };
    },
    async knownMessageIds(mailboxId, ids) {
      const { data, error } = await client.from("inbox_items").select("gmail_message_id")
        .eq("mailbox_id", mailboxId).in("gmail_message_id", ids);
      if (error) throw new Error(error.message);
      return new Set((data ?? []).map((row) => row.gmail_message_id as string));
    },
    async loadContext(familyId) {
      const { data, error } = await client.from("mail_context").select("context").eq("family_id", familyId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data?.context ?? "";
    },
    async saveItems(mailbox, items) {
      const rows = items.map(({ item, suggestion }) => ({
        family_id: mailbox.familyId,
        mailbox_id: mailbox.id,
        gmail_message_id: item.gmailMessageId,
        gmail_thread_id: item.gmailThreadId,
        sender: item.sender,
        subject: item.subject,
        received_at: item.receivedAt,
        link: item.link,
        suggestion,
        analyzed_at: new Date().toISOString(),
      }));
      // Mails that were already saved are skipped, so the script may send the same mail again.
      const { data, error } = await client.from("inbox_items")
        .upsert(rows, { onConflict: "mailbox_id,gmail_message_id", ignoreDuplicates: true })
        .select("id");
      if (error) throw new Error(error.message);
      return data?.length ?? 0;
    },
    async loadDeviceTokens(familyId) {
      const { data, error } = await client.from("device_tokens").select("token").eq("family_id", familyId);
      if (error) throw new Error(error.message);
      return (data ?? []).map((row) => row.token as string);
    },
    async deleteDeviceTokens(tokens) {
      const { error } = await client.from("device_tokens").delete().in("token", tokens);
      if (error) throw new Error(error.message);
    },
  };
}

// The tests import this file and set MAIL_INTAKE_TEST so that no server is started.
if (!Deno.env.get("MAIL_INTAKE_TEST")) {
  const store = await createStore();
  const analyze = createAnthropicAnalyzer(
    Deno.env.get("ANTHROPIC_API_KEY"),
    Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-5-5",
  );
  const today = () => new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Berlin" }).format(new Date());
  const keyPem = Deno.env.get("APNS_KEY_P8");
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const apns: ApnsConfig | null = keyPem && keyId && teamId
    ? { keyPem, keyId, teamId, topic: Deno.env.get("APNS_TOPIC") ?? "de.babranyi.familyplanner" }
    : null;
  if (!apns) console.error("push is off: APNS_KEY_P8, APNS_KEY_ID or APNS_TEAM_ID is not set");
  const push = createApnsSender(apns);
  Deno.serve((req) => handleRequest(req, { store, analyze, push, today }));
}
