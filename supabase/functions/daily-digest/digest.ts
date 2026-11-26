// What the morning and evening push says. Pure functions, no database and no network, so they are easy to test.
//
// The rules for "which items happen on a day" mirror WeekBuilder.swift in the app: a one-off item happens on its
// start day; a series happens on its weekdays from its start day until its end day, and not on holidays if it
// skips them. There is no pickup on holidays.

export type Slot = "morning" | "evening";

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

export interface FamilyData {
  items: CalendarItem[];
  /** Pickup time by ISO weekday. */
  pickups: Record<number, string>;
  holidays: Holiday[];
  /** Tasks that are not done and have a due date. */
  tasks: OpenTask[];
}

export interface DayPlan {
  date: string;
  pickup: string | null;
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

export function planDay(data: FamilyData, date: string): DayPlan {
  const weekday = isoWeekday(date);
  const holiday = data.holidays.find((h) => h.startsOn <= date && date <= h.endsOn) ?? null;
  const items = data.items
    .filter((item) => occurs(item, date, weekday, holiday !== null))
    .sort((a, b) => hhmm(a.atTime).localeCompare(hhmm(b.atTime)));
  const due = data.tasks
    .filter((task) => task.dueOn === date)
    .sort((a, b) => (a.dueTime ?? "99:99").localeCompare(b.dueTime ?? "99:99"));
  const pickup = holiday ? null : data.pickups[weekday] ?? null;
  const cash = [...items, ...due].reduce((sum, entry) => sum + (entry.cashCents ?? 0), 0);
  return {
    date,
    pickup: pickup ? hhmm(pickup) : null,
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
  if (plan.pickup) lines.push(`Abholung ${plan.pickup}`);
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
