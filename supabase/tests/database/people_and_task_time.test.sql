-- Tests for people without an account and the task time (pgTAP). All people and data are invented.
begin;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'alex@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'sam@example.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'helper@example.test'),
  ('00000000-0000-0000-0000-0000000000a4', 'stranger@example.test');

insert into public.families (id, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'Test Family'),
  ('00000000-0000-0000-0000-0000000000f2', 'Other Family');

insert into public.family_members (family_id, user_id, display_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Alex', 'admin'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a2', 'Sam', 'family'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a3', 'Helper', 'guest'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000a4', 'Stranger', 'admin');

-- Privileges are granted explicitly in this project; the app's role needs them on the new table
select ok(has_table_privilege('authenticated', 'public.household_people', 'SELECT'),
  'signed-in users have privileges on the people table');
select ok(not has_table_privilege('anon', 'public.household_people', 'SELECT'),
  'anon has no privileges on the people table');

-- Admin (alex) adds a child without an account
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select lives_ok(
  $$insert into public.household_people (id, family_id, display_name)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1', 'Kid')$$,
  'an admin can add a person without an account'
);
select lives_ok(
  $$insert into public.tasks (family_id, title, assignee_person, due_on, due_time)
    values ('00000000-0000-0000-0000-0000000000f1', 'Costume', '00000000-0000-0000-0000-0000000000c1',
            '2026-12-04', '08:15')$$,
  'a task can go to a person without an account, with a time'
);
select throws_ok(
  $$insert into public.tasks (family_id, title, assignee, assignee_person)
    values ('00000000-0000-0000-0000-0000000000f1', 'Both',
            '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1')$$,
  '23514', null, 'a task cannot have two assignees'
);
select throws_ok(
  $$insert into public.tasks (family_id, title, due_time)
    values ('00000000-0000-0000-0000-0000000000f1', 'Time without date', '08:15')$$,
  '23514', null, 'a time needs a date'
);
select lives_ok(
  $$insert into public.calendar_items (family_id, title, starts_on, assignee_person)
    values ('00000000-0000-0000-0000-0000000000f1', 'School play', '2026-12-10',
            '00000000-0000-0000-0000-0000000000c1')$$,
  'a calendar item can go to a person without an account'
);
reset role;

-- A person of another family cannot be assigned
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a4","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.tasks (family_id, title, assignee_person)
    values ('00000000-0000-0000-0000-0000000000f2', 'Foreign', '00000000-0000-0000-0000-0000000000c1')$$,
  '23503', null, 'a person of another family cannot be assigned'
);
select is((select count(*)::int from public.household_people), 0, 'other families do not see the person');
reset role;

-- Family member (sam) can read but not manage people
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.household_people), 1, 'a family member can read the people');
select throws_ok(
  $$insert into public.household_people (family_id, display_name)
    values ('00000000-0000-0000-0000-0000000000f1', 'Intruder')$$,
  '42501', null, 'a family member cannot add people'
);
reset role;

-- Guest sees nobody
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.household_people), 0, 'a guest does not see the people');
reset role;

-- Removing a person unassigns instead of deleting the task
delete from public.household_people where id = '00000000-0000-0000-0000-0000000000c1';
select is((select assignee_person from public.tasks where title = 'Costume'), null,
  'deleting a person unassigns their tasks');

select * from finish();
rollback;
