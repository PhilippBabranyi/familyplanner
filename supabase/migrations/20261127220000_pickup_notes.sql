-- "Mitnehmen" notes for the school days of a child.
--
-- - pickup_notes: what has to be taken along on a weekday ("Buch zurückbringen"). A row is valid from its
--   valid_from day until a later row for the same weekday starts: a new rhythm is just new rows with a new
--   date, and the old ones stay as history. An empty note means "nothing to take along from that day on".
-- - pickup_note_overrides: a note for a single day (empty = nothing that day).
-- - the digest slot 'leave' (the nudge when the family leaves the house) was already allowed by the previous
--   migration and is sent once per day.

create table public.pickup_notes (
  family_id uuid not null references public.families (id) on delete cascade,
  person_id uuid not null,
  -- ISO weekday: 1 = Monday ... 7 = Sunday.
  weekday smallint not null check (weekday between 1 and 7),
  valid_from date not null,
  note text not null default '' check (length(note) <= 200),
  primary key (family_id, person_id, weekday, valid_from),
  foreign key (family_id, person_id) references public.household_people (family_id, id) on delete cascade
);

create table public.pickup_note_overrides (
  family_id uuid not null references public.families (id) on delete cascade,
  person_id uuid not null,
  day date not null,
  note text not null default '' check (length(note) <= 200),
  primary key (family_id, person_id, day),
  foreign key (family_id, person_id) references public.household_people (family_id, id) on delete cascade
);

alter table public.pickup_notes enable row level security;
alter table public.pickup_note_overrides enable row level security;

create policy pickup_notes_select on public.pickup_notes
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_notes_insert on public.pickup_notes
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_notes_update on public.pickup_notes
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_notes_delete on public.pickup_notes
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

create policy pickup_note_overrides_select on public.pickup_note_overrides
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_note_overrides_insert on public.pickup_note_overrides
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_note_overrides_update on public.pickup_note_overrides
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy pickup_note_overrides_delete on public.pickup_note_overrides
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

revoke all on public.pickup_notes, public.pickup_note_overrides from anon, authenticated;
grant select, insert, update, delete on public.pickup_notes, public.pickup_note_overrides to authenticated;
grant select on public.pickup_notes, public.pickup_note_overrides to service_role;

