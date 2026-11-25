// Run with: MAIL_INTAKE_TEST=1 deno test --allow-env supabase/functions/mail-intake
import { assertEquals } from "jsr:@std/assert@1";
import {
  type Filters,
  handleRequest,
  hashToken,
  type IntakeItem,
  type Mailbox,
  MAX_ITEMS,
  type Store,
  validateItems,
} from "./index.ts";

const TOKEN = "t".repeat(32);

function fakeStore(overrides: Partial<Store> = {}) {
  const calls = { touched: [] as string[], saved: [] as IntakeItem[][] };
  const store: Store = {
    findMailboxByHash: async (hash) => {
      const known = await hashToken(TOKEN);
      return hash === known ? { id: "mb1", familyId: "fam1" } : null;
    },
    touch: (id) => {
      calls.touched.push(id);
      return Promise.resolve();
    },
    loadFilters: (): Promise<Filters> => Promise.resolve({ senders: ["school.example"], keywords: ["Frist"] }),
    saveItems: (_mailbox: Mailbox, items: IntakeItem[]) => {
      calls.saved.push(items);
      return Promise.resolve(items.length);
    },
    ...overrides,
  };
  return { store, calls };
}

function request(body: unknown, headers: Record<string, string> = { "x-mailbox-token": TOKEN }, method = "POST") {
  return new Request("https://example.test/mail-intake", {
    method,
    headers,
    body: method === "POST" ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined,
  });
}

const validItem = {
  gmailMessageId: "18c0ffee",
  gmailThreadId: "18c0ffed",
  sender: "Teacher <teacher@school.example>",
  subject: "Zoo trip",
  receivedAt: "2026-12-01T08:00:00Z",
  link: "https://mail.google.com/mail/u/0/#all/18c0ffed",
};

Deno.test("hashToken matches the known SHA-256 of 'abc'", async () => {
  assertEquals(
    await hashToken("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("only POST is accepted", async () => {
  const { store } = fakeStore();
  const response = await handleRequest(request(null, { "x-mailbox-token": TOKEN }, "GET"), store);
  assertEquals(response.status, 405);
});

Deno.test("a missing token is rejected", async () => {
  const { store } = fakeStore();
  const response = await handleRequest(request({ action: "filters" }, {}), store);
  assertEquals(response.status, 401);
});

Deno.test("an unknown token is rejected and nothing is touched", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(
    request({ action: "filters" }, { "x-mailbox-token": "x".repeat(32) }),
    store,
  );
  assertEquals(response.status, 401);
  assertEquals(calls.touched.length, 0);
});

Deno.test("filters are returned and the mailbox is marked as seen", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(request({ action: "filters" }), store);
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { senders: ["school.example"], keywords: ["Frist"] });
  assertEquals(calls.touched, ["mb1"]);
});

Deno.test("valid items are saved", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(request({ action: "items", items: [validItem] }), store);
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { saved: 1 });
  assertEquals(calls.saved[0][0].receivedAt, "2026-12-01T08:00:00.000Z");
});

Deno.test("an empty item list saves nothing", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(request({ action: "items", items: [] }), store);
  assertEquals(await response.json(), { saved: 0 });
  assertEquals(calls.saved.length, 0);
});

Deno.test("items with a link outside Gmail are rejected", async () => {
  const { store, calls } = fakeStore();
  const bad = { ...validItem, link: "https://evil.example/phish" };
  const response = await handleRequest(request({ action: "items", items: [bad] }), store);
  assertEquals(response.status, 400);
  assertEquals(calls.saved.length, 0);
});

Deno.test("too many items are rejected", () => {
  const many = Array.from({ length: MAX_ITEMS + 1 }, () => validItem);
  assertEquals(validateItems(many), null);
});

Deno.test("malformed items are rejected", () => {
  assertEquals(validateItems("nope"), null);
  assertEquals(validateItems([{ ...validItem, gmailMessageId: "bad id!" }]), null);
  assertEquals(validateItems([{ ...validItem, receivedAt: "yesterday-ish" }]), null);
  assertEquals(validateItems([{ ...validItem, sender: 42 }]), null);
});

Deno.test("long subjects are shortened instead of rejected", () => {
  const items = validateItems([{ ...validItem, subject: "s".repeat(900) }]);
  assertEquals(items?.[0].subject.length, 500);
});

Deno.test("invalid JSON and unknown actions are rejected", async () => {
  const { store } = fakeStore();
  assertEquals((await handleRequest(request("{not json"), store)).status, 400);
  assertEquals((await handleRequest(request({ action: "delete-everything" }), store)).status, 400);
});

Deno.test("oversized bodies are rejected", async () => {
  const { store } = fakeStore();
  const response = await handleRequest(request("x".repeat(300 * 1024)), store);
  assertEquals(response.status, 413);
});

Deno.test("database errors do not leak details", async () => {
  const { store } = fakeStore({
    loadFilters: () => Promise.reject(new Error("relation mail_filters secret detail")),
  });
  const response = await handleRequest(request({ action: "filters" }), store);
  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "server error" });
});
