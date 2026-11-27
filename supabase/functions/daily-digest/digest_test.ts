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
  leaveNudge,
  bringNote,
  type ChildData,
  cleanupDue,
  pickupReminders,
  pickupSlot,
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

const kim: ChildData = {
  id: "c-kim",
  name: "Kim",
  pickupNotes: [
    { weekday: 3, validFrom: "2026-09-01", note: "Book back, PE kit" },
    { weekday: 4, validFrom: "2026-09-01", note: "Ballet bag" },
    { weekday: 4, validFrom: "2027-01-11", note: "" },
  ],
  pickupNoteOverrides: { "2026-12-17": "Swimming kit", "2026-12-02": "" },
  pickups: { 1: "15:20:00", 4: "16:20:00" },
  pickupRemind: { 1: 30, 4: 45 },
  pickupOverrides: { "2026-12-14": "13:00:00", "2026-12-15": null },
  pickupDrivers: { "2026-12-03": { id: "u-sam", name: "Sam" } },
};

/** The same family with changes to Kim's pickup. */
const withKim = (family: FamilyData, patch: Partial<ChildData>): FamilyData => ({
  ...family,
  children: [{ ...family.children[0], ...patch }, ...family.children.slice(1)],
});

/** The first reminder that is due, or null. */
const firstReminder = (family: FamilyData, at: Clock) => pickupReminders(family, at)[0] ?? null;

const data: FamilyData = {
  children: [kim],
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
  holidays: [{ name: "Herbstferien", startsOn: "2026-12-10", endsOn: "2026-12-12" }],
  tasks: [
    { title: "Kostümtag", assignee: "Kim", dueOn: "2026-12-03", dueTime: "08:15:00", cashCents: 500 },
    { title: "Steuer", assignee: null, dueOn: "2026-11-20", dueTime: null, cashCents: null },
  ],
};

Deno.test("a day collects pickup, items, tasks, overdue tasks and cash", () => {
  const plan = planDay(data, "2026-12-03");
  assertEquals(plan.children[0].pickup, "16:20");
  assertEquals(plan.items.map((i) => i.title), ["Zahnarzt", "Ballet"]);
  assertEquals(plan.tasksDue.map((t) => t.title), ["Kostümtag"]);
  assertEquals(plan.overdue, 1);
  assertEquals(plan.cashCents, 2500);
});

Deno.test("series skip holidays, and there is no pickup on a holiday", () => {
  const plan = planDay(data, "2026-12-10");
  assertEquals(plan.holiday, "Herbstferien");
  assertEquals(plan.children[0].pickup, null);
  assertEquals(plan.items, []);
});

Deno.test("a series ends after its last day", () => {
  const ended: FamilyData = { ...data, items: [{ ...data.items[0], repeatUntil: "2026-11-30" }] };
  assertEquals(planDay(ended, "2026-12-03").items, []);
});

Deno.test("the morning message lists the facts of the day", () => {
  const { title, body } = buildDigest("morning", planDay(data, "2026-12-03"), () => 0);
  assertStringIncludes(title, "Guten Morgen");
  assertStringIncludes(body, "Pickup Kim 16:20 (Sam)");
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
  const empty: FamilyData = { children: [], items: [], holidays: [], tasks: [] };
  assertEquals(buildDigest("morning", planDay(empty, "2026-12-05"), () => 0).body, "Heute steht nichts an. Einen schönen Tag!");
  assertEquals(buildDigest("evening", planDay(empty, "2026-12-05"), () => 0).body, "Morgen steht nichts an. Gute Nacht!");
});

Deno.test("long days are shortened", () => {
  const many: FamilyData = {
    items: Array.from({ length: 7 }, (_, i) => ({
      title: `Termin ${i}`, startsOn: "2026-12-05", atTime: `1${i}:00:00`, weekdays: [], repeatUntil: null,
      skipHolidays: false, assignee: null, cashCents: null,
    })),
    children: [], holidays: [], tasks: [],
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
  assertEquals(monday.children[0].pickup, "15:20");
  assertEquals(monday.children[0].pickupDriver, null);
  const morning = buildDigest("morning", monday, () => 0);
  assertEquals(morning.title, "☀️ Guten Morgen! Das steht heute an");
  assertEquals(morning.body.split("\n")[0], "🚗 Pickup Kim 15:20: noch niemand eingetragen");
  assertEquals(buildDigest("evening", monday, () => 0).title, "🌙 Morgen auf dem Plan");
});

Deno.test("days without a pickup do not ask who picks up", () => {
  const tuesday = planDay(data, "2026-12-08");
  assertEquals(tuesday.children[0].pickup, null);
  assertEquals(buildDigest("morning", tuesday, () => 0).body.includes("niemand eingetragen"), false);
});

const thursday = (hour: number, minute: number): Clock => ({ date: "2026-12-03", weekday: 4, minutes: hour * 60 + minute });

Deno.test("the reminder goes to the driver from the lead time until the pickup", () => {
  // Pickup 16:20, lead time 45 minutes: from 15:35.
  assertEquals(firstReminder(data, thursday(15, 34)), null);
  const due = firstReminder(data, thursday(15, 35));
  assertEquals(due?.driverId, "u-sam");
  assertStringIncludes(due?.message.body ?? "", "16:20");
  assertEquals(firstReminder(data, thursday(16, 19))?.driverId, "u-sam");
  assertEquals(firstReminder(data, thursday(16, 20)), null);
});

Deno.test("no reminder without a driver, without a pickup or on a holiday", () => {
  const monday: Clock = { date: "2026-12-07", weekday: 1, minutes: 15 * 60 };
  assertEquals(firstReminder(data, monday), null);
  const tuesday: Clock = { date: "2026-12-08", weekday: 2, minutes: 15 * 60 };
  assertEquals(firstReminder(data, tuesday), null);
  const holiday = withKim(data, { pickupDrivers: { "2026-12-10": { id: "u-sam", name: "Sam" } } });
  assertEquals(firstReminder(holiday, { date: "2026-12-10", weekday: 4, minutes: 16 * 60 }), null);
});

Deno.test("a change for one day replaces the weekly pickup time, and can cancel it", () => {
  // 2026-12-14 is a Monday (weekly 15:20), 2026-12-15 a Tuesday without a weekly pickup.
  assertEquals(planDay(data, "2026-12-07").children[0].pickup, "15:20");
  assertEquals(planDay(data, "2026-12-14").children[0].pickup, "13:00");
  assertEquals(planDay(data, "2026-12-15").children[0].pickup, null);
  const cancelledMonday = withKim(data, { pickupOverrides: { "2026-12-07": null } });
  assertEquals(planDay(cancelledMonday, "2026-12-07").children[0].pickup, null);
  assertEquals(planDay(cancelledMonday, "2026-12-14").children[0].pickup, "15:20");
});

Deno.test("the reminder follows the changed time and stays away on a cancelled day", () => {
  const changed = withKim(data, { pickupOverrides: { "2026-12-03": "13:00:00" } });
  // Changed from 16:20 to 13:00, lead time 45 minutes: from 12:15.
  assertEquals(firstReminder(changed, thursday(12, 14)), null);
  assertEquals(firstReminder(changed, thursday(12, 15))?.driverId, "u-sam");
  assertEquals(firstReminder(changed, thursday(15, 35)), null);
  const cancelled = withKim(data, { pickupOverrides: { "2026-12-03": null } });
  assertEquals(firstReminder(cancelled, thursday(15, 35)), null);
});

Deno.test("old suggestions are cleaned up at night, 30 days back", () => {
  assertEquals(cleanupDue(clock(2, 2, 59)), false);
  assertEquals(cleanupDue(clock(2, 3, 0)), true);
  assertEquals(cleanupDue(clock(2, 3, 59)), true);
  assertEquals(cleanupDue(clock(2, 4, 0)), false);
  assertEquals(suggestionCutoff(new Date("2026-12-31T02:00:00Z")), "2026-12-01T02:00:00.000Z");
});

Deno.test("the rhythm decides what to take along, and a new rhythm replaces the old one", () => {
  // 2026-12-02 is a Wednesday (overridden to nothing), 2026-12-09 a Wednesday, 2026-12-03 a Thursday.
  assertEquals(bringNote(kim, "2026-12-09", false), "Book back, PE kit");
  assertEquals(bringNote(kim, "2026-12-03", false), "Ballet bag");
  // From 2027-01-14 (Thursday) the empty note of the new rhythm counts.
  assertEquals(bringNote(kim, "2027-01-14", false), null);
  // Before the first rhythm there is nothing.
  assertEquals(bringNote(kim, "2026-08-27", false), null);
});

Deno.test("a note for a single day wins over the rhythm, an empty one clears it", () => {
  assertEquals(bringNote(kim, "2026-12-17", false), "Swimming kit");
  assertEquals(bringNote(kim, "2026-12-02", false), null);
});

Deno.test("nothing is taken along in the holidays", () => {
  assertEquals(bringNote(kim, "2026-12-10", true), null);
});

Deno.test("the morning message and the evening message carry the note of their day", () => {
  assertStringIncludes(buildDigest("morning", planDay(data, "2026-12-03"), () => 0).body, "🎒 Mitnehmen: Ballet bag");
  assertStringIncludes(buildDigest("evening", planDay(data, "2026-12-03"), () => 0).body, "🎒 Mitnehmen: Ballet bag");
});

Deno.test("the nudge at 7:30 comes only on days with something to take along", () => {
  const clock = (date: string, weekday: number, minutes: number): Clock => ({ date, weekday, minutes });
  assertEquals(leaveNudge(data, clock("2026-12-03", 4, 7 * 60 + 29)), null);
  assertStringIncludes(leaveNudge(data, clock("2026-12-03", 4, 7 * 60 + 30))?.body ?? "", "Ballet bag");
  assertStringIncludes(leaveNudge(data, clock("2026-12-03", 4, 8 * 60 + 40))?.body ?? "", "Ballet bag");
  assertEquals(leaveNudge(data, clock("2026-12-03", 4, 9 * 60 + 5)), null);
  // Monday has no note.
  assertEquals(leaveNudge(data, clock("2026-12-07", 1, 7 * 60 + 30)), null);
});

// Two children: each has a pickup of their own.
const robin: ChildData = {
  id: "c-robin",
  name: "Robin",
  pickupNotes: [{ weekday: 4, validFrom: "2026-09-01", note: "Swim bag" }],
  pickupNoteOverrides: {},
  pickups: { 4: "15:30:00" },
  pickupRemind: { 4: 20 },
  pickupOverrides: {},
  pickupDrivers: { "2026-12-03": { id: "u-alex", name: "Alex" } },
};
const two: FamilyData = { ...data, children: [kim, robin] };

Deno.test("every child has a pickup line with their name", () => {
  const body = buildDigest("morning", planDay(two, "2026-12-03"), () => 0).body;
  assertStringIncludes(body, "Pickup Kim 16:20 (Sam)");
  assertStringIncludes(body, "Pickup Robin 15:30 (Alex)");
});

Deno.test("with two children the notes name the child", () => {
  const body = buildDigest("morning", planDay(two, "2026-12-03"), () => 0).body;
  assertStringIncludes(body, "🎒 Mitnehmen (Kim): Ballet bag");
  assertStringIncludes(body, "🎒 Mitnehmen (Robin): Swim bag");
  const nudge = leaveNudge(two, { date: "2026-12-03", weekday: 4, minutes: 7 * 60 + 30 });
  assertStringIncludes(nudge?.body ?? "", "Kim: Ballet bag");
  assertStringIncludes(nudge?.body ?? "", "Robin: Swim bag");
});

Deno.test("each child has a reminder of their own with their own lead time", () => {
  // Kim 16:20 minus 45 = 15:35, Robin 15:30 minus 20 = 15:10.
  assertEquals(pickupReminders(two, thursday(15, 9)).length, 0);
  assertEquals(pickupReminders(two, thursday(15, 10)).map((r) => r.driverId), ["u-alex"]);
  assertEquals(pickupReminders(two, thursday(15, 29)).map((r) => r.driverId), ["u-alex"]);
  assertEquals(pickupReminders(two, thursday(15, 30)).length, 0);
  assertEquals(pickupReminders(two, thursday(15, 36)).map((r) => r.driverId), ["u-sam"]);
  assertEquals(pickupSlot("c-robin"), "pickup:c-robin");
});
