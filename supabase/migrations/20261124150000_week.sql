-- Week overview: calendar items (one-off or weekly) and pickup times per weekday.
--
-- Same access model as tasks and shopping: admin and family read and write, guests see nothing.
-- Every table has row-level security (see CLAUDE.md).

create table public.calendar_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  note text,
  -- First (or only) day of the item. A weekly item repeats on the same weekday from this date on.
  starts_on date not null,
  at_time time not null default '00:00',
  repeats_weekly boolean not null default false,
  assignee uuid,
  -- Cash needed for this item in cents, e.g. for a babysitter.
  cash_cents integer check (cash_cents is null or cash_cents >= 0),
  created_at timestamptz not null default now(),
  foreign key (family_id, assignee)
    references public.family_members (family_id, user_id) on delete set null (assignee)
);

create table public.pickup_times (
  family_id uuid not null references public.families (id) on delete cascade,
  -- ISO weekday: 1 = Monday ... 7 = Sunday. A missing row means no pickup that day.
  weekday smallint not null check (weekday between 1 and 7),
  pickup_time time not null,
  primary key (family_id, weekday)
);

create index calendar_items_family_id_idx on public.calendar_items (family_id);
create index calendar_items_assignee_idx on public.calendar_items (family_id, assignee);

alter table public.calendar_items enable row level security;
alter table public.pickup_times enable row level security;

create policy calendar_select on public.calendar_items
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy calendar_insert on public.calendar_items
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy calendar_update on public.calendar_items
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy calendar_delete on public.calendar_items
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

create policy pickup_select on public.pickup_times
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_insert on public.pickup_times
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_update on public.pickup_times
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_delete on public.pickup_times
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

revoke all on public.calendar_items, public.pickup_times from anon, authenticated;
grant select, insert, update, delete on public.calendar_items to authenticated;
grant select, insert, update, delete on public.pickup_times to authenticated;
