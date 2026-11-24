-- Initial schema: families, members with roles, tasks, shopping list.
--
-- Security model (see CLAUDE.md): everything is protected by row-level security (RLS).
-- Roles inside a family:
--   admin  - sees and manages everything, including members
--   family - sees and edits tasks and the shopping list
--   guest  - sees only tasks assigned to them and can only change their status
-- Users who are not members of a family see nothing of it. Anonymous users see nothing at all.
--
-- A family and its first admin are created by the project owner (dashboard / SQL),
-- not through the API. There is deliberately no INSERT policy on public.families.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table public.family_members (
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null check (length(trim(display_name)) > 0),
  role text not null check (role in ('admin', 'family', 'guest')),
  created_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  assignee uuid,
  due_on date,
  status text not null default 'open' check (status in ('open', 'doing', 'done')),
  created_at timestamptz not null default now(),
  -- The assignee must be a member of the same family. Removing a member unassigns the task.
  foreign key (family_id, assignee)
    references public.family_members (family_id, user_id) on delete set null (assignee)
);

create table public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  quantity text not null default '',
  category text not null default 'other'
    check (category in ('produce', 'baking', 'household', 'other')),
  in_basket boolean not null default false,
  label text,
  created_at timestamptz not null default now()
);

create index tasks_family_id_idx on public.tasks (family_id);
create index tasks_assignee_idx on public.tasks (family_id, assignee);
create index shopping_items_family_id_idx on public.shopping_items (family_id);
create index family_members_user_id_idx on public.family_members (user_id);

-- ---------------------------------------------------------------------------
-- Helper: the current user's role in a family (null if not a member)
-- ---------------------------------------------------------------------------

create schema if not exists private;

-- SECURITY DEFINER so the lookup is not itself blocked by RLS on family_members.
-- The private schema is not exposed through the API.
create function private.family_role(target_family uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role
  from public.family_members m
  where m.family_id = target_family
    and m.user_id = (select auth.uid())
$$;

revoke all on schema private from public;
revoke all on function private.family_role(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.family_role(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.tasks enable row level security;
alter table public.shopping_items enable row level security;

-- families: members can read; only admins can rename. No insert/delete via the API.
create policy families_select on public.families
  for select to authenticated
  using (private.family_role(id) is not null);

create policy families_update on public.families
  for update to authenticated
  using (private.family_role(id) = 'admin')
  with check (private.family_role(id) = 'admin');

-- family_members: members can see each other; only admins manage membership.
create policy members_select on public.family_members
  for select to authenticated
  using (private.family_role(family_id) is not null);

create policy members_insert on public.family_members
  for insert to authenticated
  with check (private.family_role(family_id) = 'admin');

create policy members_update on public.family_members
  for update to authenticated
  using (private.family_role(family_id) = 'admin')
  with check (private.family_role(family_id) = 'admin');

create policy members_delete on public.family_members
  for delete to authenticated
  using (private.family_role(family_id) = 'admin');

-- tasks: admin and family see everything; guests only tasks assigned to them.
-- Only admin and family write directly; guests change status via set_task_status().
create policy tasks_select on public.tasks
  for select to authenticated
  using (
    private.family_role(family_id) in ('admin', 'family')
    or (private.family_role(family_id) = 'guest' and assignee = (select auth.uid()))
  );

create policy tasks_insert on public.tasks
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));

create policy tasks_update on public.tasks
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));

create policy tasks_delete on public.tasks
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

-- shopping_items: admin and family only. Guests see nothing.
create policy shopping_select on public.shopping_items
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

create policy shopping_insert on public.shopping_items
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));

create policy shopping_update on public.shopping_items
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));

create policy shopping_delete on public.shopping_items
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

-- ---------------------------------------------------------------------------
-- Table privileges: only signed-in users, never anonymous
-- ---------------------------------------------------------------------------

revoke all on public.families, public.family_members, public.tasks, public.shopping_items
  from anon, authenticated;

grant select, update on public.families to authenticated;
grant select, insert, update, delete on public.family_members to authenticated;
grant select, insert, update, delete on public.tasks to authenticated;
grant select, insert, update, delete on public.shopping_items to authenticated;

-- ---------------------------------------------------------------------------
-- Guests may move their own tasks through the states, nothing else.
-- ---------------------------------------------------------------------------

create function public.set_task_status(task_id uuid, new_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.tasks;
  caller_role text;
begin
  if new_status not in ('open', 'doing', 'done') then
    raise exception 'invalid status' using errcode = '22023';
  end if;

  select * into target from public.tasks where id = task_id;
  if not found then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  caller_role := private.family_role(target.family_id);

  if caller_role in ('admin', 'family')
     or (caller_role = 'guest' and target.assignee = (select auth.uid())) then
    update public.tasks set status = new_status where id = task_id;
  else
    raise exception 'not allowed' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.set_task_status(uuid, text) from public, anon;
grant execute on function public.set_task_status(uuid, text) to authenticated;
