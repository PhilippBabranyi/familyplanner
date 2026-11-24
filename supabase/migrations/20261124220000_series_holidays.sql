-- Series on several weekdays, an optional end date, and school holidays.
--
-- calendar_items.repeats_weekly (one weekday) is replaced by weekdays (any set of weekdays).
-- An empty weekdays array means a one-off item. Holidays pause pickups and every series that has
-- skip_holidays set. Same access model as before: admin and family read and write, guests see nothing.

alter table public.calendar_items
  add column weekdays smallint[] not null default '{}',
  add column repeat_until date,
  add column skip_holidays boolean not null default false;

update public.calendar_items
  set weekdays = array[extract(isodow from starts_on)::smallint]
  where repeats_weekly;

alter table public.calendar_items drop column repeats_weekly;

alter table public.calendar_items
  add constraint calendar_items_weekdays_valid
    check (weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]),
  add constraint calendar_items_repeat_until_valid
    check (repeat_until is null or repeat_until >= starts_on);

create table public.holidays (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create index holidays_family_id_idx on public.holidays (family_id);

alter table public.holidays enable row level security;

create policy holidays_select on public.holidays
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy holidays_insert on public.holidays
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy holidays_update on public.holidays
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy holidays_delete on public.holidays
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

revoke all on public.holidays from anon, authenticated;
grant select, insert, update, delete on public.holidays to authenticated;
