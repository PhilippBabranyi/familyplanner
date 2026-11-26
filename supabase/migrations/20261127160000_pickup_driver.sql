-- Who picks the child up on a given day, and how long before the pickup the reminder comes.
--
-- - pickup_drivers: one row per day on which somebody is responsible for the pickup. No row means that nobody
--   has been entered yet (this is the default; the morning push then asks for it). Only accounts of the family
--   can be entered.
-- - pickup_times.remind_minutes: minutes before the pickup at which the responsible person gets a reminder.
-- - digest_log learns the slot 'pickup', so that a reminder is sent only once per day.

create table public.pickup_drivers (
  family_id uuid not null references public.families (id) on delete cascade,
  day date not null,
  driver uuid not null,
  primary key (family_id, day),
  foreign key (family_id, driver)
    references public.family_members (family_id, user_id) on delete cascade
);

alter table public.pickup_drivers enable row level security;

create policy pickup_drivers_select on public.pickup_drivers
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_drivers_insert on public.pickup_drivers
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_drivers_update on public.pickup_drivers
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_drivers_delete on public.pickup_drivers
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

revoke all on public.pickup_drivers from anon, authenticated;
grant select, insert, update, delete on public.pickup_drivers to authenticated;
grant select on public.pickup_drivers to service_role;

alter table public.pickup_times
  add column remind_minutes smallint not null default 30
    check (remind_minutes between 5 and 180);

alter table public.digest_log drop constraint digest_log_slot_check;
alter table public.digest_log
  add constraint digest_log_slot_check check (slot in ('morning', 'evening', 'pickup'));

grant select on public.device_tokens to service_role;
