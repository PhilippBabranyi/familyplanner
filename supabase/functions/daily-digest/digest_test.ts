// Run with: DIGEST_TEST=1 deno test --allow-env supabase/functions/daily-digest
import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  addDays,
  berlinClock,
  buildDigest,
  type Clock,
  dueSlots,
  type FamilyData,
  formatEuro,
  isoWeekday,
  cleanupDue,
  pickupReminder,
  planDay,
  suggestionCutoff,
  targetDate,
} from "./digest.ts";

const clock = (weekday: number, hour: number, minute: number): Clock => ({
  date: "2026-12-01",
  weekday,
  minutes: hour * 60 + minute,
});

Deno.test("the morning slot is 7:00 on weekdays and 8:30 at the weekend", () => {
  assertEquals(dueSlots(clock(2, 6, 59)), []);
  assertEquals(dueSlots(clock(2, 7, 0)), ["morning"]);
  assertEquals(dueSlots(clock(5, 8, 29)), ["morning"]);
  assertEquals(dueSlots(clock(6, 7, 30)), []);
  assertEquals(dueSlots(clock(6, 8, 30)), ["morning"]);
  assertEquals(dueSlots(clock(7, 8, 30)), ["morning"]);
});

Deno.test("a missed tick is made up for, but not for hours", () => {
  assertEquals(dueSlots(clock(3, 8, 29)), ["morning"]);
  assertEquals(dueSlots(clock(3, 8, 31)), []);
});

Deno.test("the evening slot is 19:00 on every day", () => {
  for (const weekday of [1, 2, 3, 4, 5, 6, 7]) {
    assertEquals(dueSlots(clock(weekday, 18, 59)), []);
    assertEquals(dueSlots(clock(weekday, 19, 0)), ["evening"]);
    assertEquals(dueSlots(clock(weekday, 20, 29)), ["evening"]);
    assertEquals(dueSlots(clock(weekday, 20, 30)), []);
  }
});

Deno.test("the Berlin clock follows summer and winter time", () => {
  // 2026-12-01 05:59 UTC is 06:59 in Berlin (winter), 2026-07-01 05:59 UTC is 07:59 (summer).
  assertEquals(berlinClock(new Date("2026-12-01T05:59:00Z")), { date: "2026-12-01", weekday: 2, minutes: 6 * 60 + 59 });
  assertEquals(berlinClock(new Date("2026-07-01T05:59:00Z")), { date: "2026-07-01", weekday: 3, minutes: 7 * 60 + 59 });
  // Shortly after midnight UTC it is already the next day in Berlin.
  assertEquals(berlinClock(new Date("2026-12-01T23:30:00Z")).date, "2026-12-02");
});

Deno.test("date helpers", () => {
  assertEquals(addDays("2026-12-31", 1), "2027-01-01");
  assertEquals(isoWeekday("2026-11-29"), 7);
  assertEquals(isoWeekday("2026-11-30"), 1);
  assertEquals(targetDate("morning", "2026-12-01"), "2026-12-01");
  assertEquals(targetDate("evening", "2026-12-01"), "2026-12-02");
});

const data: FamilyData = {
  items: [
    {
      title: "Ballet", startsOn: "2026-11-01", atTime: "16:00:00", weekdays: [4], repeatUntil: null,
      skipHolidays: true, assignee: "Kim", cashCents: null,
    },
    {
      title: "Zahnarzt", startsOn: "2026-12-03", atTime: "09:30:00", weekdays: [], repeatUntil: null,
      skipHolidays: false, assignee: null, cashCents: 2000,
    },
  ],
  pickups: { 1: "15:20:00", 4: "16:20:00" },
  pickupRemind: { 1: 30, 4: 45 },
  pickupOverrides: { "2026-12-14": "13:00:00", "2026-12-15": null },
  pickupDrivers: { "2026-12-03": { id: "u-sam", name: "Sam" } },
  holidays: [{ name: "Herbstferien", startsOn: "2026-12-10", endsOn: "2026-12-12" }],
  tasks: [
    { title: "Kostümtag", assignee: "Kim", dueOn: "2026-12-03", dueTime: "08:15:00", cashCents: 500 },
    { title: "Steuer", assignee: null, dueOn: "2026-11-20", dueTime: null, cashCents: null },
  ],
};

Deno.test("a day collects pickup, items, tasks, overdue tasks and cash", () => {
  const plan = planDay(data, "2026-12-03");
  assertEquals(plan.pickup, "16:20");
  assertEquals(plan.items.map((i) => i.title), ["Zahnarzt", "Ballet"]);
  assertEquals(plan.tasksDue.map((t) => t.title), ["Kostümtag"]);
  assertEquals(plan.overdue, 1);
  assertEquals(plan.cashCents, 2500);
});

Deno.test("series skip holidays, and there is no pickup on a holiday", () => {
  const plan = planDay(data, "2026-12-10");
  assertEquals(plan.holiday, "Herbstferien");
  assertEquals(plan.pickup, null);
  assertEquals(plan.items, []);
});

Deno.test("a series ends after its last day", () => {
  const ended: FamilyData = { ...data, items: [{ ...data.items[0], repeatUntil: "2026-11-30" }] };
  assertEquals(planDay(ended, "2026-12-03").items, []);
});

Deno.test("the morning message lists the facts of the day", () => {
  const { title, body } = buildDigest("morning", planDay(data, "2026-12-03"), () => 0);
  assertStringIncludes(title, "Guten Morgen");
  assertStringIncludes(body, "Abholung 16:20 (Sam)");
  assertStringIncludes(body, "09:30 Zahnarzt");
  assertStringIncludes(body, "16:00 Ballet (Kim)");
  assertStringIncludes(body, "Aufgaben: Kostümtag 08:15 (Kim)");
  assertStringIncludes(body, "1 Aufgabe überfällig");
  assertStringIncludes(body, "Bargeld: 25 €");
});

Deno.test("the evening message talks about tomorrow and leaves out overdue tasks", () => {
  const plan = planDay(data, targetDate("evening", "2026-12-02"));
  const { title, body } = buildDigest("evening", plan, () => 0);
  assertStringIncludes(title, "Morgen");
  assertStringIncludes(body, "Kostümtag");
  assertEquals(body.includes("überfällig"), false);
});

Deno.test("an empty day gets a friendly line", () => {
  const empty: FamilyData = {
    items: [], pickups: {}, pickupRemind: {}, pickupDrivers: {}, pickupOverrides: {}, holidays: [], tasks: [],
  };
  assertEquals(buildDigest("morning", planDay(empty, "2026-12-05"), () => 0).body, "Heute steht nichts an. Einen schönen Tag!");
  assertEquals(buildDigest("evening", planDay(empty, "2026-12-05"), () => 0).body, "Morgen steht nichts an. Gute Nacht!");
});

Deno.test("long days are shortened", () => {
  const many: FamilyData = {
    items: Array.from({ length: 7 }, (_, i) => ({
      title: `Termin ${i}`, startsOn: "2026-12-05", atTime: `1${i}:00:00`, weekdays: [], repeatUntil: null,
      skipHolidays: false, assignee: null, cashCents: null,
    })),
    pickups: {}, pickupRemind: {}, pickupDrivers: {}, pickupOverrides: {}, holidays: [], tasks: [],
  };
  const { body } = buildDigest("morning", planDay(many, "2026-12-05"), () => 0);
  assertStringIncludes(body, "… und 3 weitere Termine");
});

Deno.test("euro amounts", () => {
  assertEquals(formatEuro(500), "5 €");
  assertEquals(formatEuro(550), "5,50 €");
  assertEquals(formatEuro(2505), "25,05 €");
});

Deno.test("an open pickup is the first line, the title stays the briefing title", () => {
  const monday = planDay(data, "2026-12-07");
  assertEquals(monday.pickup, "15:20");
  assertEquals(monday.pickupDriver, null);
  const morning = buildDigest("morning", monday, () => 0);
  assertEquals(morning.title, "☀️ Guten Morgen! Das steht heute an");
  assertEquals(morning.body.split("\n")[0], "🚗 Abholung 15:20: noch niemand eingetragen");
  assertEquals(buildDigest("evening", monday, () => 0).title, "🌙 Morgen auf dem Plan");
});

Deno.test("days without a pickup do not ask who picks up", () => {
  const tuesday = planDay(data, "2026-12-08");
  assertEquals(tuesday.pickup, null);
  assertEquals(buildDigest("morning", tuesday, () => 0).body.includes("niemand eingetragen"), false);
});

const thursday = (hour: number, minute: number): Clock => ({ date: "2026-12-03", weekday: 4, minutes: hour * 60 + minute });

Deno.test("the reminder goes to the driver from the lead time until the pickup", () => {
  // Pickup 16:20, lead time 45 minutes: from 15:35.
  assertEquals(pickupReminder(data, thursday(15, 34)), null);
  const due = pickupReminder(data, thursday(15, 35));
  assertEquals(due?.driverId, "u-sam");
  assertStringIncludes(due?.message.body ?? "", "16:20");
  assertEquals(pickupReminder(data, thursday(16, 19))?.driverId, "u-sam");
  assertEquals(pickupReminder(data, thursday(16, 20)), null);
});

Deno.test("no reminder without a driver, without a pickup or on a holiday", () => {
  const monday: Clock = { date: "2026-12-07", weekday: 1, minutes: 15 * 60 };
  assertEquals(pickupReminder(data, monday), null);
  const tuesday: Clock = { date: "2026-12-08", weekday: 2, minutes: 15 * 60 };
  assertEquals(pickupReminder(data, tuesday), null);
  const holiday: FamilyData = { ...data, pickupDrivers: { "2026-12-10": { id: "u-sam", name: "Sam" } } };
  assertEquals(pickupReminder(holiday, { date: "2026-12-10", weekday: 4, minutes: 16 * 60 }), null);
});

Deno.test("a change for one day replaces the weekly pickup time, and can cancel it", () => {
  // 2026-12-14 is a Monday (weekly 15:20), 2026-12-15 a Tuesday without a weekly pickup.
  assertEquals(planDay(data, "2026-12-07").pickup, "15:20");
  assertEquals(planDay(data, "2026-12-14").pickup, "13:00");
  assertEquals(planDay(data, "2026-12-15").pickup, null);
  const cancelledMonday: FamilyData = { ...data, pickupOverrides: { "2026-12-07": null } };
  assertEquals(planDay(cancelledMonday, "2026-12-07").pickup, null);
  assertEquals(planDay(cancelledMonday, "2026-12-14").pickup, "15:20");
});

Deno.test("the reminder follows the changed time and stays away on a cancelled day", () => {
  const changed: FamilyData = {
    ...data,
    pickupOverrides: { "2026-12-03": "13:00:00" },
  };
  // Changed from 16:20 to 13:00, lead time 45 minutes: from 12:15.
  assertEquals(pickupReminder(changed, thursday(12, 14)), null);
  assertEquals(pickupReminder(changed, thursday(12, 15))?.driverId, "u-sam");
  assertEquals(pickupReminder(changed, thursday(15, 35)), null);
  const cancelled: FamilyData = { ...data, pickupOverrides: { "2026-12-03": null } };
  assertEquals(pickupReminder(cancelled, thursday(15, 35)), null);
});

Deno.test("old suggestions are cleaned up at night, 30 days back", () => {
  assertEquals(cleanupDue(clock(2, 2, 59)), false);
  assertEquals(cleanupDue(clock(2, 3, 0)), true);
  assertEquals(cleanupDue(clock(2, 3, 59)), true);
  assertEquals(cleanupDue(clock(2, 4, 0)), false);
  assertEquals(suggestionCutoff(new Date("2026-12-31T02:00:00Z")), "2026-12-01T02:00:00.000Z");
});
