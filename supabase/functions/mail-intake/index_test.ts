// Run with: MAIL_INTAKE_TEST=1 deno test --allow-env supabase/functions/mail-intake
import { assertEquals } from "jsr:@std/assert@1";
import { type Analyzer, fallbackSuggestion, type Suggestion } from "./analyze.ts";
import type { PushMessage, PushSender } from "./push.ts";
import {
  type AnalyzedItem,
  type Dependencies,
  type Filters,
  handleRequest,
  hashToken,
  type IntakeItem,
  type Mailbox,
  MAX_ITEMS,
  MAX_MAIL_CHARS,
  type Store,
  validateItems,
} from "./index.ts";

const TOKEN = "t".repeat(32);

const suggestion: Suggestion = {
  kind: "event",
  title: "Zoo trip",
  date: "2026-12-04",
  time: "09:00",
  amount: null,
  currency: null,
  summary: "Class trip to the zoo.",
};

function fakeStore(overrides: Partial<Store> = {}) {
  const calls = { touched: [] as string[], saved: [] as AnalyzedItem[][], deleted: [] as string[] };
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
    knownMessageIds: () => Promise.resolve(new Set<string>()),
    loadContext: () => Promise.resolve("Child Test goes to Example School."),
    loadDeviceTokens: () => Promise.resolve(["token-1", "token-2"]),
    deleteDeviceTokens: (tokens) => {
      calls.deleted.push(...tokens);
      return Promise.resolve();
    },
    saveItems: (_mailbox: Mailbox, items: AnalyzedItem[]) => {
      calls.saved.push(items);
      return Promise.resolve(items.length);
    },
    ...overrides,
  };
  return { store, calls };
}

function fakePush() {
  const sent: { tokens: string[]; message: PushMessage }[] = [];
  const push: PushSender = (tokens, message) => {
    sent.push({ tokens, message });
    return Promise.resolve({ invalid: [] });
  };
  return { push, sent };
}

function deps(
  store: Store,
  analyze: Analyzer = () => Promise.resolve(suggestion),
  push: PushSender = fakePush().push,
): Dependencies {
  return { store, analyze, push, today: () => "2026-12-01" };
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
  body: "Dear parents, the class goes to the zoo on Friday 4 December. Please bring a packed lunch.",
};

Deno.test("hashToken matches the known SHA-256 of 'abc'", async () => {
  assertEquals(
    await hashToken("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("only POST is accepted", async () => {
  const { store } = fakeStore();
  const response = await handleRequest(request(null, { "x-mailbox-token": TOKEN }, "GET"), deps(store));
  assertEquals(response.status, 405);
});

Deno.test("a missing token is rejected", async () => {
  const { store } = fakeStore();
  const response = await handleRequest(request({ action: "filters" }, {}), deps(store));
  assertEquals(response.status, 401);
});

Deno.test("an unknown token is rejected and nothing is touched", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(
    request({ action: "filters" }, { "x-mailbox-token": "x".repeat(32) }),
    deps(store),
  );
  assertEquals(response.status, 401);
  assertEquals(calls.touched.length, 0);
});

Deno.test("filters are returned and the mailbox is marked as seen", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(request({ action: "filters" }), deps(store));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { senders: ["school.example"], keywords: ["Frist"] });
  assertEquals(calls.touched, ["mb1"]);
});

Deno.test("valid items are saved", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(request({ action: "items", items: [validItem] }), deps(store));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { saved: 1, handled: ["18c0ffee"] });
  assertEquals(calls.saved[0][0].item.receivedAt, "2026-12-01T08:00:00.000Z");
  assertEquals(calls.saved[0][0].suggestion, suggestion);
});

Deno.test("an empty item list saves nothing", async () => {
  const { store, calls } = fakeStore();
  const response = await handleRequest(request({ action: "items", items: [] }), deps(store));
  assertEquals(await response.json(), { saved: 0, handled: [] });
  assertEquals(calls.saved.length, 0);
});

Deno.test("items with a link outside Gmail are rejected", async () => {
  const { store, calls } = fakeStore();
  const bad = { ...validItem, link: "https://evil.example/phish" };
  const response = await handleRequest(request({ action: "items", items: [bad] }), deps(store));
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

Deno.test("the mail text is limited and optional", () => {
  const long = validateItems([{ ...validItem, body: "b".repeat(MAX_MAIL_CHARS + 500) }]);
  assertEquals(long?.[0].body.length, MAX_MAIL_CHARS);
  const { body: _body, ...withoutBody } = validItem;
  assertEquals(validateItems([withoutBody])?.[0].body, "");
});

Deno.test("the analyzer gets the mail, the family context and today's date", async () => {
  const { store } = fakeStore();
  let seen: Parameters<Analyzer>[0] | undefined;
  const analyze: Analyzer = (input) => {
    seen = input;
    return Promise.resolve(suggestion);
  };
  await handleRequest(request({ action: "items", items: [validItem] }), deps(store, analyze));
  assertEquals(seen?.subject, "Zoo trip");
  assertEquals(seen?.today, "2026-12-01");
  assertEquals(seen?.context, "Child Test goes to Example School.");
  assertEquals(seen?.body.startsWith("Dear parents"), true);
});

Deno.test("the mail text is never passed to the store", async () => {
  const { store, calls } = fakeStore();
  await handleRequest(request({ action: "items", items: [validItem] }), deps(store));
  assertEquals(JSON.stringify(calls.saved).includes("packed lunch"), false);
});

Deno.test("known mails are not analyzed again but reported as handled", async () => {
  const { store, calls } = fakeStore({ knownMessageIds: () => Promise.resolve(new Set(["18c0ffee"])) });
  let analyzed = 0;
  const analyze: Analyzer = () => {
    analyzed++;
    return Promise.resolve(suggestion);
  };
  const response = await handleRequest(request({ action: "items", items: [validItem] }), deps(store, analyze));
  assertEquals(await response.json(), { saved: 0, handled: ["18c0ffee"] });
  assertEquals(analyzed, 0);
  assertEquals(calls.saved.length, 0);
});

Deno.test("a failed analysis leaves the mail unsaved so that it is retried", async () => {
  const { store, calls } = fakeStore();
  const second = { ...validItem, gmailMessageId: "18c0ffef" };
  const analyze: Analyzer = (input) =>
    input.subject === "Zoo trip" && input.body.includes("Second")
      ? Promise.reject(new Error("api down"))
      : Promise.resolve(suggestion);
  const items = [validItem, { ...second, body: "Second mail" }];
  const response = await handleRequest(request({ action: "items", items }), deps(store, analyze));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { saved: 1, handled: ["18c0ffee"] });
  assertEquals(calls.saved[0].length, 1);
});

Deno.test("an unreadable model answer still saves the mail without a proposal", async () => {
  const { store, calls } = fakeStore();
  const analyze: Analyzer = (input) => Promise.resolve(fallbackSuggestion(input.subject));
  await handleRequest(request({ action: "items", items: [validItem] }), deps(store, analyze));
  assertEquals(calls.saved[0][0].suggestion.kind, "none");
});

Deno.test("long subjects are shortened instead of rejected", () => {
  const items = validateItems([{ ...validItem, subject: "s".repeat(900) }]);
  assertEquals(items?.[0].subject.length, 500);
});

Deno.test("invalid JSON and unknown actions are rejected", async () => {
  const { store } = fakeStore();
  assertEquals((await handleRequest(request("{not json"), deps(store))).status, 400);
  assertEquals((await handleRequest(request({ action: "delete-everything" }), deps(store))).status, 400);
});

Deno.test("oversized bodies are rejected", async () => {
  const { store } = fakeStore();
  const response = await handleRequest(request("x".repeat(600 * 1024)), deps(store));
  assertEquals(response.status, 413);
});

Deno.test("database errors do not leak details", async () => {
  const { store } = fakeStore({
    loadFilters: () => Promise.reject(new Error("relation mail_filters secret detail")),
  });
  const response = await handleRequest(request({ action: "filters" }), deps(store));
  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "server error" });
});

Deno.test("the family gets one push for new suggestions", async () => {
  const { store } = fakeStore();
  const { push, sent } = fakePush();
  await handleRequest(request({ action: "items", items: [validItem] }), deps(store, undefined, push));
  assertEquals(sent.length, 1);
  assertEquals(sent[0].tokens, ["token-1", "token-2"]);
  assertEquals(sent[0].message.body.includes("Zoo trip"), true);
});

Deno.test("several new suggestions in one run give one push", async () => {
  const { store } = fakeStore();
  const { push, sent } = fakePush();
  const second = { ...validItem, gmailMessageId: "18c0ffef" };
  await handleRequest(request({ action: "items", items: [validItem, second] }), deps(store, undefined, push));
  assertEquals(sent.length, 1);
  assertEquals(sent[0].message.body.startsWith("2 neue"), true);
});

Deno.test("mails without anything to do send no push", async () => {
  const { store } = fakeStore();
  const { push, sent } = fakePush();
  const none: Analyzer = (input) => Promise.resolve(fallbackSuggestion(input.subject));
  await handleRequest(request({ action: "items", items: [validItem] }), deps(store, none, push));
  assertEquals(sent.length, 0);
});

Deno.test("dead tokens are removed after a push", async () => {
  const { store, calls } = fakeStore();
  const push: PushSender = () => Promise.resolve({ invalid: ["token-2"] });
  await handleRequest(request({ action: "items", items: [validItem] }), deps(store, undefined, push));
  assertEquals(calls.deleted, ["token-2"]);
});

Deno.test("a failing push does not fail the intake", async () => {
  const { store } = fakeStore();
  const push: PushSender = () => Promise.reject(new Error("apns down"));
  const response = await handleRequest(request({ action: "items", items: [validItem] }), deps(store, undefined, push));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).saved, 1);
});
