// Run with: DIGEST_TEST=1 deno test --allow-env supabase/functions/daily-digest
import { assertEquals } from "jsr:@std/assert@1";
import { type Dependencies, handleRequest, type Store } from "./index.ts";
import type { FamilyData } from "./digest.ts";
import type { PushMessage } from "./push.ts";

const SECRET = "s".repeat(32);
const emptyData: FamilyData = { items: [], pickups: {}, holidays: [], tasks: [] };

function setup(options: { now: string; tokens?: string[]; failLoad?: boolean; claimed?: string[] }) {
  const claimed = new Set(options.claimed ?? []);
  const pushes: { tokens: string[]; message: PushMessage }[] = [];
  const deleted: string[] = [];
  const store: Store = {
    loadFamilyIds: () => Promise.resolve(["f1"]),
    loadFamilyData: () => options.failLoad ? Promise.reject(new Error("db down")) : Promise.resolve(emptyData),
    claimSlot: (family, day, slot) => {
      const key = `${family}|${day}|${slot}`;
      if (claimed.has(key)) return Promise.resolve(false);
      claimed.add(key);
      return Promise.resolve(true);
    },
    releaseSlot: (family, day, slot) => {
      claimed.delete(`${family}|${day}|${slot}`);
      return Promise.resolve();
    },
    loadDeviceTokens: () => Promise.resolve(options.tokens ?? ["t1", "t2"]),
    deleteDeviceTokens: (tokens) => {
      deleted.push(...tokens);
      return Promise.resolve();
    },
  };
  const deps: Dependencies = {
    store,
    push: (tokens, message) => {
      pushes.push({ tokens, message });
      return Promise.resolve({ invalid: tokens.includes("dead") ? ["dead"] : [] });
    },
    now: () => new Date(options.now),
    secret: SECRET,
    random: () => 0,
  };
  return { deps, pushes, deleted, claimed };
}

const call = (deps: Dependencies, headers: Record<string, string> = { "x-digest-secret": SECRET }, method = "POST") =>
  handleRequest(new Request("https://example.test/daily-digest", { method, headers }), deps);

// 2026-12-01 is a Tuesday; Berlin is UTC+1 in winter.
const TUESDAY_0705 = "2026-12-01T06:05:00Z";

Deno.test("rejects calls without the right secret", async () => {
  const { deps, pushes } = setup({ now: TUESDAY_0705 });
  assertEquals((await call(deps, {})).status, 401);
  assertEquals((await call(deps, { "x-digest-secret": "x".repeat(32) })).status, 401);
  assertEquals((await call({ ...deps, secret: undefined })).status, 401);
  assertEquals((await call(deps, { "x-digest-secret": SECRET }, "GET")).status, 405);
  assertEquals(pushes.length, 0);
});

Deno.test("sends the morning digest once, however often the timer calls", async () => {
  const { deps, pushes } = setup({ now: TUESDAY_0705 });
  const first = await (await call(deps)).json();
  assertEquals(first.sent, ["morning"]);
  const second = await (await call(deps)).json();
  assertEquals(second.sent, []);
  assertEquals(pushes.length, 1);
  assertEquals(pushes[0].tokens, ["t1", "t2"]);
});

Deno.test("sends nothing outside the slots", async () => {
  const { deps, pushes } = setup({ now: "2026-12-01T12:00:00Z" });
  const body = await (await call(deps)).json();
  assertEquals(body.due, []);
  assertEquals(pushes.length, 0);
});

Deno.test("sends the evening digest at 19:00", async () => {
  const { deps, pushes } = setup({ now: "2026-12-01T18:02:00Z" });
  assertEquals((await (await call(deps)).json()).sent, ["evening"]);
  assertEquals(pushes.length, 1);
});

Deno.test("dead tokens are removed", async () => {
  const { deps, deleted } = setup({ now: TUESDAY_0705, tokens: ["t1", "dead"] });
  await call(deps);
  assertEquals(deleted, ["dead"]);
});

Deno.test("a failure gives the slot back so the next call tries again", async () => {
  const failing = setup({ now: TUESDAY_0705, failLoad: true });
  const response = await call(failing.deps);
  assertEquals((await response.json()).sent, []);
  assertEquals(failing.claimed.size, 0);
  assertEquals(failing.pushes.length, 0);
});

Deno.test("a family without phones still uses up the slot", async () => {
  const { deps, pushes, claimed } = setup({ now: TUESDAY_0705, tokens: [] });
  await call(deps);
  assertEquals(pushes.length, 0);
  assertEquals(claimed.size, 1);
});
