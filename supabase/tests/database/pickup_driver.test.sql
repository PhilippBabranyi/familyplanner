-- Tests for the pickup driver and the reminder lead time (pgTAP). All people and data are invented.
begin;
select plan(14);

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

insert into public.pickup_times (family_id, weekday, pickup_time) values
  ('00000000-0000-0000-0000-0000000000f1', 4, '16:20');
insert into public.pickup_drivers (family_id, day, driver) values
  ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', '00000000-0000-0000-0000-0000000000a2');

-- Constraints
select is(
  (select remind_minutes from public.pickup_times where weekday = 4), 30::smallint,
  'the reminder comes 30 minutes before by default'
);
select throws_ok(
  $$update public.pickup_times set remind_minutes = 2$$,
  '23514', null, 'the lead time cannot be shorter than 5 minutes'
);
select throws_ok(
  $$update public.pickup_times set remind_minutes = 181$$,
  '23514', null, 'the lead time cannot be longer than 3 hours'
);
select throws_ok(
  $$insert into public.pickup_drivers (family_id, day, driver)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-04', '00000000-0000-0000-0000-0000000000a4')$$,
  '23503', null, 'somebody outside the family cannot be entered'
);
select throws_ok(
  $$insert into public.pickup_drivers (family_id, day, driver)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', '00000000-0000-0000-0000-0000000000a1')$$,
  '23505', null, 'one driver per day'
);
select lives_ok(
  $$insert into public.digest_log (family_id, day, slot)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', 'pickup')$$,
  'the pickup reminder is a slot of its own'
);

-- Privileges
select ok(has_table_privilege('service_role', 'public.pickup_drivers', 'SELECT'), 'the Edge Function can read drivers');
select ok(has_table_privilege('service_role', 'public.device_tokens', 'SELECT'), 'the Edge Function can read tokens');
select ok(not has_table_privilege('anon', 'public.pickup_drivers', 'SELECT'), 'anon cannot read drivers');

-- Row-level security
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
select is((select count(*) from public.pickup_drivers), 1::bigint, 'family sees the drivers of its own family');
select lives_ok(
  $$insert into public.pickup_drivers (family_id, day, driver)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-04', '00000000-0000-0000-0000-0000000000a1')$$,
  'family can enter a driver'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
select is((select count(*) from public.pickup_drivers), 0::bigint, 'a guest sees no drivers');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a4","role":"authenticated"}', true);
select is((select count(*) from public.pickup_drivers), 0::bigint, 'another family sees no drivers');
select throws_ok(
  $$insert into public.pickup_drivers (family_id, day, driver)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-05', '00000000-0000-0000-0000-0000000000a1')$$,
  '42501', null, 'another family cannot enter a driver'
);

select * from finish();
rollback;
