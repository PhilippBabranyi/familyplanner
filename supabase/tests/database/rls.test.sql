-- Row-level security tests (pgTAP). Run with: supabase test db
-- All people and data here are invented.
begin;
select plan(22);

-- ---------------------------------------------------------------------------
-- Fixtures (inserted as the superuser, so RLS does not apply yet)
-- ---------------------------------------------------------------------------
-- Users: alex = admin, sam = family, helper = guest, stranger = member of another family only.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'alex@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'sam@example.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'helper@example.test'),
  ('00000000-0000-0000-0000-0000000000a4', 'stranger@example.test'),
  ('00000000-0000-0000-0000-0000000000a5', 'newbie@example.test');

insert into public.families (id, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'Test Family'),
  ('00000000-0000-0000-0000-0000000000f2', 'Other Family');

insert into public.family_members (family_id, user_id, display_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Alex', 'admin'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a2', 'Sam', 'family'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a3', 'Helper', 'guest'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000a4', 'Stranger', 'admin');

insert into public.tasks (id, family_id, title, assignee) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000f1', 'Buy a gift', '00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000f1', 'Clean windows', '00000000-0000-0000-0000-0000000000a3'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000f1', 'Bake a cake', '00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000f2', 'Other family task', null);

insert into public.shopping_items (family_id, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'Tomatoes'),
  ('00000000-0000-0000-0000-0000000000f2', 'Other family item');

-- ---------------------------------------------------------------------------
-- Structure
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0,
  'row-level security is enabled on every table in public'
);

select throws_ok(
  $$insert into public.family_members (family_id, user_id, display_name, role)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a5', 'Newbie', 'superuser')$$,
  '23514',
  null,
  'unknown roles are rejected'
);

select throws_ok(
  $$insert into public.tasks (family_id, title, assignee)
    values ('00000000-0000-0000-0000-0000000000f1', 'Wrong assignee', '00000000-0000-0000-0000-0000000000a4')$$,
  '23503',
  null,
  'a task cannot be assigned to someone outside the family'
);

-- ---------------------------------------------------------------------------
-- Anonymous users
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok('select * from public.tasks', '42501', null, 'anon cannot read tasks');
select throws_ok('select * from public.shopping_items', '42501', null, 'anon cannot read the shopping list');
reset role;

-- ---------------------------------------------------------------------------
-- Admin (alex)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.tasks), 3, 'admin sees all tasks of their family and none of others');
select is((select count(*)::int from public.family_members), 3, 'admin sees the members of their family');
select lives_ok(
  $$insert into public.family_members (family_id, user_id, display_name, role)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a5', 'Newbie', 'guest')$$,
  'admin can add a member'
);
reset role;

-- ---------------------------------------------------------------------------
-- Family member (sam)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.tasks), 3, 'family member sees all tasks of their family');
select is((select count(*)::int from public.shopping_items), 1, 'family member sees the shopping list of their family only');
select lives_ok(
  $$insert into public.shopping_items (family_id, name)
    values ('00000000-0000-0000-0000-0000000000f1', 'Butter')$$,
  'family member can add shopping items'
);
select throws_ok(
  $$insert into public.shopping_items (family_id, name)
    values ('00000000-0000-0000-0000-0000000000f2', 'Sneaky item')$$,
  '42501',
  null,
  'family member cannot add items to another family'
);
select throws_ok(
  $$insert into public.family_members (family_id, user_id, display_name, role)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a4', 'Stranger', 'admin')$$,
  '42501',
  null,
  'family member cannot add members'
);
reset role;

-- ---------------------------------------------------------------------------
-- Guest (helper)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.tasks), 1, 'guest sees only the task assigned to them');
select is((select count(*)::int from public.shopping_items), 0, 'guest cannot see the shopping list');
select throws_ok(
  $$insert into public.shopping_items (family_id, name)
    values ('00000000-0000-0000-0000-0000000000f1', 'Guest item')$$,
  '42501',
  null,
  'guest cannot add shopping items'
);
select is_empty(
  $$update public.tasks set title = 'Hacked' where id = '00000000-0000-0000-0000-0000000000b2' returning id$$,
  'guest cannot edit a task directly'
);
select lives_ok(
  $$select public.set_task_status('00000000-0000-0000-0000-0000000000b2', 'done')$$,
  'guest can move their own task to another status'
);
select throws_ok(
  $$select public.set_task_status('00000000-0000-0000-0000-0000000000b3', 'done')$$,
  '42501',
  null,
  'guest cannot change the status of a task assigned to someone else'
);
reset role;

select is(
  (select status from public.tasks where id = '00000000-0000-0000-0000-0000000000b2'),
  'done',
  'the guest status change was saved'
);

-- ---------------------------------------------------------------------------
-- Outsider (stranger, member of another family only)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a4","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.tasks where family_id = '00000000-0000-0000-0000-0000000000f1'),
  0,
  'a member of another family cannot see this family''s tasks'
);
select throws_ok(
  $$select public.set_task_status('00000000-0000-0000-0000-0000000000b1', 'done')$$,
  '42501',
  null,
  'a member of another family cannot change this family''s tasks'
);
reset role;

select * from finish();
rollback;
