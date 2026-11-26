-- People without an account (for example a child) and a time of day for tasks.
--
-- - household_people: members of the household who never sign in. They can be picked as the person
--   responsible for tasks and calendar items. Only an admin manages them; admin and family can read them.
-- - tasks and calendar_items get a second, optional assignee column (assignee_person). At most one of the two
--   assignee columns is set.
-- - tasks get an optional time of day (due_time), only together with a date.

create table public.household_people (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  display_name text not null check (length(trim(display_name)) > 0),
  created_at timestamptz not null default now(),
  unique (family_id, id)
);

create index household_people_family_id_idx on public.household_people (family_id);

alter table public.household_people enable row level security;
revoke all on public.household_people from anon;

create policy people_select on public.household_people
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy people_insert on public.household_people
  for insert to authenticated
  with check (private.family_role(family_id) = 'admin');
create policy people_update on public.household_people
  for update to authenticated
  using (private.family_role(family_id) = 'admin')
  with check (private.family_role(family_id) = 'admin');
create policy people_delete on public.household_people
  for delete to authenticated
  using (private.family_role(family_id) = 'admin');

-- The person must belong to the same family as the task or item. Removing a person unassigns.
alter table public.tasks
  add column assignee_person uuid,
  add column due_time time,
  add constraint tasks_one_assignee check (assignee is null or assignee_person is null),
  add constraint tasks_time_needs_date check (due_time is null or due_on is not null),
  add constraint tasks_assignee_person_fkey foreign key (family_id, assignee_person)
    references public.household_people (family_id, id) on delete set null (assignee_person);

alter table public.calendar_items
  add column assignee_person uuid,
  add constraint calendar_one_assignee check (assignee is null or assignee_person is null),
  add constraint calendar_assignee_person_fkey foreign key (family_id, assignee_person)
    references public.household_people (family_id, id) on delete set null (assignee_person);

create index tasks_assignee_person_idx on public.tasks (family_id, assignee_person);
create index calendar_items_assignee_person_idx on public.calendar_items (family_id, assignee_person);
