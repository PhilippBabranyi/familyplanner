// Edge Function `mail-intake`.
//
// Receives metadata of mails from the small script in a family member's Google account
// (integrations/gmail-apps-script). The request is authenticated with a secret token per mailbox;
// only the SHA-256 hash of the token is stored in the database.
//
// Deploy with "Verify JWT" switched OFF (the script is not a Supabase user); the token is the credential.
// The function uses the service role key that Supabase provides to every Edge Function at runtime.
// Nothing secret is stored in this file.

export interface IntakeItem {
  gmailMessageId: string;
  gmailThreadId: string;
  sender: string;
  subject: string;
  receivedAt: string;
  link: string;
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
  saveItems(mailbox: Mailbox, items: IntakeItem[]): Promise<number>;
}

export const MAX_BODY_BYTES = 256 * 1024;
export const MAX_ITEMS = 50;

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

export async function handleRequest(req: Request, store: Store): Promise<Response> {
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
      const saved = items.length === 0 ? 0 : await store.saveItems(mailbox, items);
      return json({ saved });
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
    async saveItems(mailbox, items) {
      const rows = items.map((item) => ({
        family_id: mailbox.familyId,
        mailbox_id: mailbox.id,
        gmail_message_id: item.gmailMessageId,
        gmail_thread_id: item.gmailThreadId,
        sender: item.sender,
        subject: item.subject,
        received_at: item.receivedAt,
        link: item.link,
      }));
      // Mails that were already saved are skipped, so the script may send the same mail again.
      const { data, error } = await client.from("inbox_items")
        .upsert(rows, { onConflict: "mailbox_id,gmail_message_id", ignoreDuplicates: true })
        .select("id");
      if (error) throw new Error(error.message);
      return data?.length ?? 0;
    },
  };
}

// The tests import this file and set MAIL_INTAKE_TEST so that no server is started.
if (!Deno.env.get("MAIL_INTAKE_TEST")) {
  const store = await createStore();
  Deno.serve((req) => handleRequest(req, store));
}
