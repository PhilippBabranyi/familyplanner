-- A pickup that differs on a single day, like one changed occurrence of a series.
--
-- One row per day. pickup_time is the changed time; null means that there is no pickup on that day.
-- A day without a row uses the weekly pickup time (pickup_times).

create table public.pickup_overrides (
  family_id uuid not null references public.families (id) on delete cascade,
  day date not null,
  pickup_time time,
  primary key (family_id, day)
);

alter table public.pickup_overrides enable row level security;

create policy pickup_overrides_select on public.pickup_overrides
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_overrides_insert on public.pickup_overrides
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_overrides_update on public.pickup_overrides
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_overrides_delete on public.pickup_overrides
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

revoke all on public.pickup_overrides from anon, authenticated;
grant select, insert, update, delete on public.pickup_overrides to authenticated;
grant select on public.pickup_overrides to service_role;
