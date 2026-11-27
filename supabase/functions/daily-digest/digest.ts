// What the morning and evening push says. Pure functions, no database and no network, so they are easy to test.
//
// The rules for "which items happen on a day" mirror WeekBuilder.swift in the app: a one-off item happens on its
// start day; a series happens on its weekdays from its start day until its end day, and not on holidays if it
// skips them. There is no pickup on holidays.

export type Slot = "morning" | "evening";

/** The slots that are written to digest_log: the two digests, the pickup reminder of a child and the nudge at leaving. */
export type LogSlot = Slot | "leave" | `pickup:${string}`;

export interface CalendarItem {
  title: string;
  startsOn: string;
  /** "07:30" or "07:30:00" */
  atTime: string;
  /** ISO weekdays, 1 = Monday ... 7 = Sunday. Empty for a one-off item. */
  weekdays: number[];
  repeatUntil: string | null;
  skipHolidays: boolean;
  assignee: string | null;
  cashCents: number | null;
}

export interface Holiday {
  name: string;
  startsOn: string;
  endsOn: string;
}

export interface OpenTask {
  title: string;
  assignee: string | null;
  dueOn: string;
  dueTime: string | null;
  cashCents: number | null;
}

/** What has to be taken along on a weekday, from `validFrom` on. An empty note means nothing. */
export interface PickupNote {
  weekday: number;
  validFrom: string;
  note: string;
}

/** The pickup of one child: times, who picks up, changes for single days and what to take along. */
export interface ChildData {
  id: string;
  /** First name of the child; the pickup is called "Pickup <name>". */
  name: string;
  /** The "take along" rhythm: a note counts from its start day until a later one for the same weekday. */
  pickupNotes: PickupNote[];
  /** Notes for single days (`yyyy-MM-dd`); an empty one means nothing that day. */
  pickupNoteOverrides: Record<string, string>;
  /** Pickup time by ISO weekday. */
  pickups: Record<number, string>;
  /** Minutes before the pickup at which the reminder comes, by ISO weekday. */
  pickupRemind: Record<number, number>;
  /** Changes for single days (`yyyy-MM-dd`): the changed time, or null if there is no pickup that day. */
  pickupOverrides: Record<string, string | null>;
  /** Who picks up on which day (`yyyy-MM-dd`). A day that is missing has nobody entered yet. */
  pickupDrivers: Record<string, { id: string; name: string }>;
}

export interface FamilyData {
  /** The children that have a pickup. */
  children: ChildData[];
  items: CalendarItem[];
  holidays: Holiday[];
  /** Tasks that are not done and have a due date. */
  tasks: OpenTask[];
}

/** The pickup of one child on one day. */
export interface ChildDay {
  childId: string;
  /** "Pickup Kim" */
  label: string;
  pickup: string | null;
  /** Name of the person who picks up, or null if nobody is entered. */
  pickupDriver: string | null;
  /** What to take along that day, or null. */
  bring: string | null;
}

export interface DayPlan {
  date: string;
  /** One entry per child. */
  children: ChildDay[];
  holiday: string | null;
  items: { time: string; title: string; assignee: string | null }[];
  tasksDue: { title: string; time: string | null; assignee: string | null }[];
  overdue: number;
  cashCents: number;
}

export interface Clock {
  /** `yyyy-MM-dd` in Europe/Berlin */
  date: string;
  /** ISO weekday, 1 = Monday ... 7 = Sunday */
  weekday: number;
  minutes: number;
}

const BERLIN = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/Berlin",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  weekday: "short",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

const WEEKDAYS: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

/** The wall clock in Berlin for a moment in time. */
export function berlinClock(moment: Date): Clock {
  const parts: Record<string, string> = {};
  for (const part of BERLIN.formatToParts(moment)) parts[part.type] = part.value;
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    weekday: WEEKDAYS[parts.weekday] ?? 1,
    minutes: Number(parts.hour) * 60 + Number(parts.minute),
  };
}

/** Minutes after midnight at which a slot is due: 7:00 on weekdays and 8:30 on weekends, 19:00 every evening. */
export function slotMinutes(slot: Slot, weekday: number): number {
  if (slot === "evening") return 19 * 60;
  return weekday >= 6 ? 8 * 60 + 30 : 7 * 60;
}

/** A missed tick is made up for within this time; later the slot is skipped. */
export const CATCH_UP_MINUTES = 90;

/** Mail suggestions older than this many days are deleted, decided or not. */
export const SUGGESTION_KEEP_DAYS = 30;

/** The cleanup runs in the night, from 3:00 for an hour. It is safe to run it more than once. */
export function cleanupDue(clock: Clock): boolean {
  return clock.minutes >= 3 * 60 && clock.minutes < 4 * 60;
}

/** Suggestions created before this moment are deleted. */
export function suggestionCutoff(moment: Date): string {
  return new Date(moment.getTime() - SUGGESTION_KEEP_DAYS * 24 * 3600 * 1000).toISOString();
}

/** The slots that are due right now (usually none or one). */
export function dueSlots(clock: Clock): Slot[] {
  const due: Slot[] = [];
  for (const slot of ["morning", "evening"] as const) {
    const start = slotMinutes(slot, clock.weekday);
    if (clock.minutes >= start && clock.minutes < start + CATCH_UP_MINUTES) due.push(slot);
  }
  return due;
}

export function addDays(date: string, days: number): string {
  const [year, month, day] = date.split("-").map(Number);
  const moved = new Date(Date.UTC(year, month - 1, day + days));
  return moved.toISOString().slice(0, 10);
}

/** ISO weekday of a `yyyy-MM-dd` date. */
export function isoWeekday(date: string): number {
  const [year, month, day] = date.split("-").map(Number);
  const raw = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return raw === 0 ? 7 : raw;
}

function hhmm(time: string): string {
  return time.slice(0, 5);
}

function occurs(item: CalendarItem, date: string, weekday: number, inHoliday: boolean): boolean {
  if (item.weekdays.length === 0) return item.startsOn === date;
  if (!item.weekdays.includes(weekday) || item.startsOn > date) return false;
  if (item.repeatUntil && date > item.repeatUntil) return false;
  return !(item.skipHolidays && inHoliday);
}

/** What a child takes along on a day: the note for that single day, else the rhythm. Nothing in the holidays. */
export function bringNote(child: ChildData, date: string, inHoliday: boolean): string | null {
  if (inHoliday) return null;
  const single = child.pickupNoteOverrides[date];
  if (single !== undefined) return single.trim() || null;
  const weekday = isoWeekday(date);
  let current: PickupNote | null = null;
  for (const note of child.pickupNotes) {
    if (note.weekday !== weekday || note.validFrom > date) continue;
    if (!current || note.validFrom > current.validFrom) current = note;
  }
  return current?.note.trim() || null;
}

/** How the pickup of a child is called. */
export function pickupLabel(child: ChildData): string {
  return `Pickup ${child.name}`;
}

export function planChild(child: ChildData, date: string, inHoliday: boolean): ChildDay {
  const changed = date in child.pickupOverrides;
  const regular = child.pickups[isoWeekday(date)] ?? null;
  const pickup = inHoliday ? null : changed ? child.pickupOverrides[date] : regular;
  return {
    childId: child.id,
    label: pickupLabel(child),
    pickup: pickup ? hhmm(pickup) : null,
    pickupDriver: pickup ? child.pickupDrivers[date]?.name ?? null : null,
    bring: bringNote(child, date, inHoliday),
  };
}

export function planDay(data: FamilyData, date: string): DayPlan {
  const weekday = isoWeekday(date);
  const holiday = data.holidays.find((h) => h.startsOn <= date && date <= h.endsOn) ?? null;
  const items = data.items
    .filter((item) => occurs(item, date, weekday, holiday !== null))
    .sort((a, b) => hhmm(a.atTime).localeCompare(hhmm(b.atTime)));
  const due = data.tasks
    .filter((task) => task.dueOn === date)
    .sort((a, b) => (a.dueTime ?? "99:99").localeCompare(b.dueTime ?? "99:99"));
  const cash = [...items, ...due].reduce((sum, entry) => sum + (entry.cashCents ?? 0), 0);
  return {
    date,
    children: data.children.map((child) => planChild(child, date, holiday !== null)),
    holiday: holiday?.name ?? null,
    items: items.map((i) => ({ time: hhmm(i.atTime), title: i.title, assignee: i.assignee })),
    tasksDue: due.map((t) => ({ title: t.title, time: t.dueTime ? hhmm(t.dueTime) : null, assignee: t.assignee })),
    overdue: data.tasks.filter((task) => task.dueOn < date).length,
    cashCents: cash,
  };
}

export function formatEuro(cents: number): string {
  const euros = Math.floor(cents / 100);
  const rest = cents % 100;
  return rest === 0 ? `${euros} €` : `${euros},${String(rest).padStart(2, "0")} €`;
}

const MORNING_TITLES = ["☀️ Guten Morgen! Das steht heute an", "🌤️ Der Tag im Überblick", "☕ Moin! Heute auf dem Plan"];
const EVENING_TITLES = ["🌙 Morgen auf dem Plan", "🎒 Kurz vorausgeschaut: morgen", "🌆 Guten Abend! Das kommt morgen"];

const MAX_ITEM_LINES = 4;
const MAX_TASK_NAMES = 3;

/** "Pickup Kim" -> "Kim" */
function nameOfLabel(label: string): string {
  return label.replace(/^Pickup /, "");
}

function withPerson(title: string, person: string | null): string {
  return person ? `${title} (${person})` : title;
}

/** The push for a slot: playful title, then the facts of the day, shortest first. */
export function buildDigest(
  slot: Slot,
  plan: DayPlan,
  random: () => number = Math.random,
): { title: string; body: string } {
  const titles = slot === "morning" ? MORNING_TITLES : EVENING_TITLES;
  const title = titles[Math.floor(random() * titles.length) % titles.length];
  const lines: string[] = [];
  if (plan.holiday) lines.push(`Ferien: ${plan.holiday}`);
  for (const child of plan.children) {
    if (!child.pickup) continue;
    lines.push(
      child.pickupDriver
        ? `${child.label} ${child.pickup} (${child.pickupDriver})`
        : `🚗 ${child.label} ${child.pickup}: noch niemand eingetragen`,
    );
  }
  for (const child of plan.children) {
    if (child.bring) lines.push(`🎒 Mitnehmen${plan.children.length > 1 ? ` (${nameOfLabel(child.label)})` : ""}: ${child.bring}`);
  }
  for (const item of plan.items.slice(0, MAX_ITEM_LINES)) {
    lines.push(`${item.time} ${withPerson(item.title, item.assignee)}`);
  }
  if (plan.items.length > MAX_ITEM_LINES) lines.push(`… und ${plan.items.length - MAX_ITEM_LINES} weitere Termine`);
  if (plan.tasksDue.length > 0) {
    const names = plan.tasksDue.slice(0, MAX_TASK_NAMES).map((t) =>
      withPerson(t.time ? `${t.title} ${t.time}` : t.title, t.assignee)
    );
    const more = plan.tasksDue.length > MAX_TASK_NAMES ? ` und ${plan.tasksDue.length - MAX_TASK_NAMES} weitere` : "";
    lines.push(`Aufgaben: ${names.join(", ")}${more}`);
  }
  if (slot === "morning" && plan.overdue > 0) {
    lines.push(plan.overdue === 1 ? "1 Aufgabe überfällig" : `${plan.overdue} Aufgaben überfällig`);
  }
  if (plan.cashCents > 0) lines.push(`Bargeld: ${formatEuro(plan.cashCents)}`);
  if (lines.length === 0) {
    lines.push(slot === "morning" ? "Heute steht nichts an. Einen schönen Tag!" : "Morgen steht nichts an. Gute Nacht!");
  }
  return { title, body: lines.join("\n") };
}

/** The day a slot talks about: today for the morning, tomorrow for the evening. */
export function targetDate(slot: Slot, today: string): string {
  return slot === "morning" ? today : addDays(today, 1);
}

export interface PickupReminder {
  childId: string;
  /** Account that has to leave soon. */
  driverId: string;
  message: { title: string; body: string };
}

/**
 * The reminders "time to leave" for today's pickups that are due: from `remind_minutes` before the pickup until the
 * pickup itself (a missed tick is made up for), only for children with somebody entered and not in the holidays.
 */
export function pickupReminders(data: FamilyData, clock: Clock): PickupReminder[] {
  const plan = planDay(data, clock.date);
  const due: PickupReminder[] = [];
  for (const child of data.children) {
    const day = plan.children.find((entry) => entry.childId === child.id);
    const driver = child.pickupDrivers[clock.date];
    if (!day?.pickup || !driver) continue;
    const [hours, minutes] = day.pickup.split(":").map(Number);
    const pickupAt = hours * 60 + minutes;
    const lead = child.pickupRemind[clock.weekday] ?? Object.values(child.pickupRemind)[0] ?? 30;
    if (clock.minutes < pickupAt - lead || clock.minutes >= pickupAt) continue;
    due.push({
      childId: child.id,
      driverId: driver.id,
      message: { title: "🚗 Zeit zum Losfahren", body: `${day.label} um ${day.pickup}. Du holst heute ab.` },
    });
  }
  return due;
}

/** The digest_log slot of the pickup reminder of a child. */
export function pickupSlot(childId: string): LogSlot {
  return `pickup:${childId}`;
}

/** The nudge when the family leaves the house. */
export const LEAVE_MINUTES = 7 * 60 + 30;

/**
 * "Did you think of ...?" at 7:30, only on days with something to take along. A missed tick is made up for
 * within the catch-up time.
 */
export function leaveNudge(data: FamilyData, clock: Clock): { title: string; body: string } | null {
  if (clock.minutes < LEAVE_MINUTES || clock.minutes >= LEAVE_MINUTES + CATCH_UP_MINUTES) return null;
  const notes = planDay(data, clock.date).children.filter((child) => child.bring);
  if (notes.length === 0) return null;
  const body = notes.length === 1 && data.children.length === 1
    ? `Habt ihr daran gedacht? ${notes[0].bring}`
    : ["Habt ihr daran gedacht?", ...notes.map((child) => `${nameOfLabel(child.label)}: ${child.bring}`)].join("\n");
  return { title: "🎒 Gleich geht's los", body };
}
