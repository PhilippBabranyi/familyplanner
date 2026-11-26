// Edge Function `daily-digest`.
//
// Sends the family a push with the day: in the morning (7:00 on weekdays, 8:30 at the weekend) what is on today,
// in the evening (19:00) what is on tomorrow. A timer in the database (pg_cron) calls this function every few
// minutes; the function decides itself whether a slot is due and sends each slot at most once per day.
//
// Deploy with "Verify JWT" switched OFF. The caller proves itself with the header `x-digest-secret`, which must
// match the Supabase secret DIGEST_SECRET. The push uses the same secrets as `mail-intake`
// (APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID). Nothing secret is stored in this file.

import {
  berlinClock,
  buildDigest,
  type Clock,
  dueSlots,
  type FamilyData,
  type LogSlot,
  pickupReminder,
  planDay,
  type Slot,
  targetDate,
} from "./digest.ts";
import { type ApnsConfig, createApnsSender, type PushSender } from "./push.ts";

/** Everything the handler needs from the database. Replaced by a fake in the tests. */
export interface Store {
  loadFamilyIds(): Promise<string[]>;
  loadFamilyData(familyId: string): Promise<FamilyData>;
  /** True if this call reserved the slot; false if it was already sent (or reserved) for that day. */
  claimSlot(familyId: string, day: string, slot: LogSlot): Promise<boolean>;
  /** Gives a reservation back after a failure, so that the next call can try again. */
  releaseSlot(familyId: string, day: string, slot: LogSlot): Promise<void>;
  /** The push addresses of the family, or only those of one account. */
  loadDeviceTokens(familyId: string, userId?: string): Promise<string[]>;
  deleteDeviceTokens(tokens: string[]): Promise<void>;
}

export interface Dependencies {
  store: Store;
  push: PushSender;
  now: () => Date;
  secret: string | undefined;
  random?: () => number;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

/** Compares without stopping at the first difference. */
function sameSecret(given: string, expected: string): boolean {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}

async function sendSlot(familyId: string, clock: Clock, slot: Slot, deps: Dependencies): Promise<boolean> {
  // The reservation comes first: two overlapping calls must not both send.
  if (!(await deps.store.claimSlot(familyId, clock.date, slot))) return false;
  try {
    const data = await deps.store.loadFamilyData(familyId);
    const message = buildDigest(slot, planDay(data, targetDate(slot, clock.date)), deps.random);
    const tokens = await deps.store.loadDeviceTokens(familyId);
    if (tokens.length === 0) return true;
    const { invalid } = await deps.push(tokens, message);
    if (invalid.length > 0) await deps.store.deleteDeviceTokens(invalid);
    return true;
  } catch (error) {
    await deps.store.releaseSlot(familyId, clock.date, slot);
    throw error;
  }
}

/** Sends "time to leave" to the person who picks up, once per day. Returns true if it was sent. */
async function sendPickupReminder(familyId: string, clock: Clock, deps: Dependencies): Promise<boolean> {
  const data = await deps.store.loadFamilyData(familyId);
  const reminder = pickupReminder(data, clock);
  if (!reminder) return false;
  if (!(await deps.store.claimSlot(familyId, clock.date, "pickup"))) return false;
  try {
    const tokens = await deps.store.loadDeviceTokens(familyId, reminder.driverId);
    if (tokens.length === 0) return true;
    const { invalid } = await deps.push(tokens, reminder.message);
    if (invalid.length > 0) await deps.store.deleteDeviceTokens(invalid);
    return true;
  } catch (error) {
    await deps.store.releaseSlot(familyId, clock.date, "pickup");
    throw error;
  }
}

export async function handleRequest(req: Request, deps: Dependencies): Promise<Response> {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const given = req.headers.get("x-digest-secret");
  if (!deps.secret || deps.secret.length < 20 || !given || !sameSecret(given, deps.secret)) {
    return json({ error: "unauthorized" }, 401);
  }
  try {
    const clock = berlinClock(deps.now());
    const slots = dueSlots(clock);
    const sent: string[] = [];
    for (const familyId of await deps.store.loadFamilyIds()) {
      for (const slot of slots) {
        try {
          if (await sendSlot(familyId, clock, slot, deps)) sent.push(slot);
        } catch (error) {
          console.error("digest failed", error instanceof Error ? error.message : "unknown error");
        }
      }
      try {
        if (await sendPickupReminder(familyId, clock, deps)) sent.push("pickup");
      } catch (error) {
        console.error("pickup reminder failed", error instanceof Error ? error.message : "unknown error");
      }
    }
    return json({ date: clock.date, due: slots, sent });
  } catch (error) {
    console.error("daily-digest failed", error instanceof Error ? error.message : "unknown error");
    return json({ error: "server error" }, 500);
  }
}

/** Yesterday in UTC is early enough for every Berlin day that can matter, and keeps the old rows out. */
function yesterday(): string {
  return new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
}

async function createStore(): Promise<Store> {
  const { createClient } = await import("jsr:@supabase/supabase-js@2");
  const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const fail = (error: { message: string } | null) => {
    if (error) throw new Error(error.message);
  };
  return {
    async loadFamilyIds() {
      const { data, error } = await client.from("families").select("id");
      fail(error);
      return (data ?? []).map((row) => row.id as string);
    },
    async loadFamilyData(familyId) {
      const [items, pickups, holidays, tasks, accounts, people, drivers] = await Promise.all([
        client.from("calendar_items")
          .select("title,starts_on,at_time,weekdays,repeat_until,skip_holidays,assignee,assignee_person,cash_cents")
          .eq("family_id", familyId),
        client.from("pickup_times").select("weekday,pickup_time,remind_minutes").eq("family_id", familyId),
        client.from("holidays").select("name,starts_on,ends_on").eq("family_id", familyId),
        client.from("tasks")
          .select("title,assignee,assignee_person,due_on,due_time,cash_cents")
          .eq("family_id", familyId).neq("status", "done").not("due_on", "is", null),
        client.from("family_members").select("user_id,display_name").eq("family_id", familyId),
        client.from("household_people").select("id,display_name").eq("family_id", familyId),
        client.from("pickup_drivers").select("day,driver").eq("family_id", familyId).gte("day", yesterday()),
      ]);
      for (const result of [items, pickups, holidays, tasks, accounts, people, drivers]) fail(result.error);
      const names = new Map<string, string>();
      for (const row of accounts.data ?? []) names.set(row.user_id as string, row.display_name as string);
      for (const row of people.data ?? []) names.set(row.id as string, row.display_name as string);
      const nameOf = (account: string | null, person: string | null) => names.get(account ?? person ?? "") ?? null;
      const pickupTimes: Record<number, string> = {};
      const pickupRemind: Record<number, number> = {};
      for (const row of pickups.data ?? []) {
        pickupTimes[row.weekday as number] = row.pickup_time as string;
        pickupRemind[row.weekday as number] = row.remind_minutes as number;
      }
      const pickupDrivers: Record<string, { id: string; name: string }> = {};
      for (const row of drivers.data ?? []) {
        const id = row.driver as string;
        pickupDrivers[row.day as string] = { id, name: names.get(id) ?? "?" };
      }
      return {
        items: (items.data ?? []).map((row) => ({
          title: row.title as string,
          startsOn: row.starts_on as string,
          atTime: row.at_time as string,
          weekdays: (row.weekdays as number[] | null) ?? [],
          repeatUntil: (row.repeat_until as string | null) ?? null,
          skipHolidays: Boolean(row.skip_holidays),
          assignee: nameOf(row.assignee as string | null, row.assignee_person as string | null),
          cashCents: (row.cash_cents as number | null) ?? null,
        })),
        pickups: pickupTimes,
        pickupRemind,
        pickupDrivers,
        holidays: (holidays.data ?? []).map((row) => ({
          name: row.name as string,
          startsOn: row.starts_on as string,
          endsOn: row.ends_on as string,
        })),
        tasks: (tasks.data ?? []).map((row) => ({
          title: row.title as string,
          assignee: nameOf(row.assignee as string | null, row.assignee_person as string | null),
          dueOn: row.due_on as string,
          dueTime: (row.due_time as string | null) ?? null,
          cashCents: (row.cash_cents as number | null) ?? null,
        })),
      };
    },
    async claimSlot(familyId, day, slot) {
      const { data, error } = await client.from("digest_log")
        .upsert({ family_id: familyId, day, slot }, { onConflict: "family_id,day,slot", ignoreDuplicates: true })
        .select("slot");
      fail(error);
      return (data?.length ?? 0) > 0;
    },
    async releaseSlot(familyId, day, slot) {
      const { error } = await client.from("digest_log").delete()
        .eq("family_id", familyId).eq("day", day).eq("slot", slot);
      fail(error);
    },
    async loadDeviceTokens(familyId, userId) {
      let query = client.from("device_tokens").select("token").eq("family_id", familyId);
      if (userId) query = query.eq("user_id", userId);
      const { data, error } = await query;
      fail(error);
      return (data ?? []).map((row) => row.token as string);
    },
    async deleteDeviceTokens(tokens) {
      const { error } = await client.from("device_tokens").delete().in("token", tokens);
      fail(error);
    },
  };
}

// The tests import this file and set DIGEST_TEST so that no server is started.
if (!Deno.env.get("DIGEST_TEST")) {
  const store = await createStore();
  const keyPem = Deno.env.get("APNS_KEY_P8");
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const apns: ApnsConfig | null = keyPem && keyId && teamId
    ? { keyPem, keyId, teamId, topic: Deno.env.get("APNS_TOPIC") ?? "de.babranyi.familyplanner" }
    : null;
  if (!apns) console.error("push is off: APNS_KEY_P8, APNS_KEY_ID or APNS_TEAM_ID is not set");
  const push = createApnsSender(apns);
  const secret = Deno.env.get("DIGEST_SECRET");
  Deno.serve((req) => handleRequest(req, { store, push, now: () => new Date(), secret }));
}
