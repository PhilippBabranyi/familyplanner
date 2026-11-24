-- Row-level security tests for the week tables (pgTAP). All people and data are invented.
begin;
select plan(11);

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

insert into public.calendar_items (family_id, title, starts_on, at_time, repeats_weekly) values
  ('00000000-0000-0000-0000-0000000000f1', 'Piano', '2026-11-27', '07:30', true),
  ('00000000-0000-0000-0000-0000000000f2', 'Other family item', '2026-11-27', '09:00', false);

insert into public.pickup_times (family_id, weekday, pickup_time) values
  ('00000000-0000-0000-0000-0000000000f1', 4, '16:20'),
  ('00000000-0000-0000-0000-0000000000f2', 4, '15:00');

-- Constraints
select throws_ok(
  $$insert into public.pickup_times (family_id, weekday, pickup_time)
    values ('00000000-0000-0000-0000-0000000000f1', 8, '15:20')$$,
  '23514', null, 'weekday must be between 1 and 7'
);
select throws_ok(
  $$insert into public.calendar_items (family_id, title, starts_on, cash_cents)
    values ('00000000-0000-0000-0000-0000000000f1', 'Negative cash', '2026-11-27', -1)$$,
  '23514', null, 'cash amounts cannot be negative'
);
select throws_ok(
  $$insert into public.calendar_items (family_id, title, starts_on, assignee)
    values ('00000000-0000-0000-0000-0000000000f1', 'Wrong assignee', '2026-11-27',
            '00000000-0000-0000-0000-0000000000a4')$$,
  '23503', null, 'an item cannot be assigned to someone outside the family'
);

-- Anonymous
set local role anon;
select throws_ok('select * from public.calendar_items', '42501', null, 'anon cannot read calendar items');
select throws_ok('select * from public.pickup_times', '42501', null, 'anon cannot read pickup times');
reset role;

-- Family member
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.calendar_items), 1, 'family member sees only their own family items');
select is((select count(*)::int from public.pickup_times), 1, 'family member sees only their own pickup times');
select lives_ok(
  $$insert into public.calendar_items (family_id, title, starts_on)
    values ('00000000-0000-0000-0000-0000000000f1', 'Swimming', '2026-11-28')$$,
  'family member can add items'
);
select throws_ok(
  $$insert into public.calendar_items (family_id, title, starts_on)
    values ('00000000-0000-0000-0000-0000000000f2', 'Sneaky item', '2026-11-28')$$,
  '42501', null, 'family member cannot add items to another family'
);
reset role;

-- Guest
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.calendar_items), 0, 'guest sees no calendar items');
select is((select count(*)::int from public.pickup_times), 0, 'guest sees no pickup times');
reset role;

select * from finish();
rollback;
