// Run with: MAIL_INTAKE_TEST=1 deno test --allow-env supabase/functions/mail-intake
import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import type { Suggestion } from "./analyze.ts";
import { buildPushMessage, createApnsJwt, createApnsSender } from "./push.ts";

const task: Suggestion = {
  kind: "task",
  title: "Costume day",
  date: "2026-12-04",
  time: null,
  amount: 5,
  currency: "GBP",
  summary: "Bring a costume.",
};
const event: Suggestion = { ...task, kind: "event", title: "Zoo trip" };

/** A throwaway key, generated for the test run. */
async function testKeyPem(): Promise<string> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let text = "";
  for (const byte of der) text += String.fromCharCode(byte);
  return `-----BEGIN PRIVATE KEY-----\n${btoa(text)}\n-----END PRIVATE KEY-----`;
}

Deno.test("a single suggestion gets a playful title and its own title in the body", () => {
  const message = buildPushMessage([task], () => 0);
  assertNotEquals(message.title, "");
  assertEquals(message.body.startsWith("Costume day"), true);
});

Deno.test("events and tasks get different playful titles", () => {
  assertNotEquals(buildPushMessage([task], () => 0).title, buildPushMessage([event], () => 0).title);
});

Deno.test("several suggestions are summarised with their number", () => {
  const message = buildPushMessage([task, event, task], () => 0.99);
  assertEquals(message.body.startsWith("3 neue"), true);
});

Deno.test("the APNs token is a signed ES256 JWT with key id and team id", async () => {
  const jwt = await createApnsJwt(await testKeyPem(), "KEY1234567", "TEAM123456", 1_800_000_000);
  const [header, claims, signature] = jwt.split(".");
  const decode = (part: string) => JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/")));
  assertEquals(decode(header), { alg: "ES256", kid: "KEY1234567" });
  assertEquals(decode(claims), { iss: "TEAM123456", iat: 1_800_000_000 });
  assertEquals(signature.length > 80, true);
});

Deno.test("the sender posts to APNs for each token and reports dead tokens", async () => {
  const calls: { url: string; headers: Record<string, string>; body: string }[] = [];
  const impl = ((url: string, init: RequestInit) => {
    calls.push({ url, headers: init.headers as Record<string, string>, body: String(init.body) });
    const dead = url.endsWith("/dead");
    return Promise.resolve(
      dead ? new Response(JSON.stringify({ reason: "Unregistered" }), { status: 410 }) : new Response("", { status: 200 }),
    );
  }) as unknown as typeof fetch;
  const config = {
    keyPem: await testKeyPem(),
    keyId: "KEY1234567",
    teamId: "TEAM123456",
    topic: "de.example.app",
    host: "https://apns.example.test",
  };
  const result = await createApnsSender(config, impl)(["good", "dead"], { title: "Hi", body: "There" });
  assertEquals(result.invalid, ["dead"]);
  assertEquals(calls.map((c) => c.url), [
    "https://apns.example.test/3/device/good",
    "https://apns.example.test/3/device/dead",
  ]);
  assertEquals(calls[0].headers["apns-topic"], "de.example.app");
  assertEquals(calls[0].headers["apns-push-type"], "alert");
  assertEquals(calls[0].headers.authorization.startsWith("bearer "), true);
  assertEquals(JSON.parse(calls[0].body).aps.alert, { title: "Hi", body: "There" });
});

Deno.test("without configuration or tokens nothing is sent", async () => {
  let called = false;
  const impl = (() => {
    called = true;
    return Promise.resolve(new Response(""));
  }) as unknown as typeof fetch;
  assertEquals(await createApnsSender(null, impl)(["t"], { title: "a", body: "b" }), { invalid: [] });
  assertEquals(called, false);
});
