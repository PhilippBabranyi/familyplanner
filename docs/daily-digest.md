# Daily digest push

Every morning and evening the family gets one push with the day.

| When | What |
|---|---|
| 7:00 Monday to Friday, 8:30 Saturday and Sunday | what is on **today** |
| 19:00 every day | what is on **tomorrow** |

Content: holiday, pickup time, calendar items, tasks due, overdue tasks (morning only) and the cash to take along.
Times are Berlin time. They are fixed in `supabase/functions/daily-digest/digest.ts`.

## Pickup: who and when to leave

- On the week screen the card "Abholung" has a menu "Wer holt ab?". Nobody is entered by default (table
  `pickup_drivers`, one row per day). If a day with a pickup has nobody, the morning and evening push say so
  ("Wer holt heute ab?").
- The person who is entered gets the push "Zeit zum Losfahren" `remind_minutes` before the pickup (30 by default,
  set in "Abholung & Ferien"). Only that person's phones get it. It is sent once per day (slot `pickup`).
- A single day can differ from the weekly time (table `pickup_overrides`): the card has "Nur dieser Tag" with a
  changed time, "Abholung entfällt" and "Auf normale Zeit zurücksetzen". The digest and the reminder use it.
- Setup: apply `supabase/migrations/20261127160000_pickup_driver.sql` and
  `supabase/migrations/20261127180000_pickup_overrides.sql`, then deploy the new version of the function.

## Bell and cleanup

- The bell also lists today's (if not over) and tomorrow's pickup when nobody is entered, with a button per person.
- Every night between 3:00 and 4:00 the function deletes mail suggestions (`inbox_items`) older than 30 days,
  whether they were decided or not. The response then has a field `cleaned` with the number. No setup needed.

## How it works

A timer in the database (pg_cron) calls the Edge Function `daily-digest` every 5 minutes. The function checks the
Berlin clock; if a slot is due and has not been sent today (table `digest_log`), it sends the push to all registered
phones of the family. A tick that is missed is made up for within 90 minutes.

## Setup (once, by the owner)

1. Apply the migration `supabase/migrations/20261127140000_daily_digest.sql` in the SQL Editor.
2. Create the Edge Function `daily-digest` (Edge Functions, "Via Editor"), with the files `index.ts`, `digest.ts`
   and `push.ts` from `supabase/functions/daily-digest/`. Switch **Verify JWT off**.
3. Add the secret `DIGEST_SECRET` (a long random string, at least 20 characters). The push uses the same secrets
   as `mail-intake` (`APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`).
4. Enable the extensions **pg_cron** and **pg_net** (Dashboard, Integrations).
5. Create the timer in the SQL Editor. Replace the two placeholders; do not commit the real values anywhere:

```sql
select cron.schedule(
  'daily-digest',
  '*/5 * * * *',
  $$select net.http_post(
    url := 'https://<PROJECT-REF>.supabase.co/functions/v1/daily-digest',
    headers := jsonb_build_object('content-type', 'application/json', 'x-digest-secret', '<DIGEST_SECRET>'),
    body := '{}'::jsonb
  )$$
);
```

To stop it: `select cron.unschedule('daily-digest');`

## Checking

- The call returns JSON such as `{"date":"2026-12-01","due":["morning"],"sent":["morning"]}`; see the Edge Function
  logs. `"due":[]` outside the slots is normal.
- To send a slot again on the same day, delete its row: `delete from public.digest_log where day = current_date;`
