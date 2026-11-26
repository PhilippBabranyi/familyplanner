-- Tests for single-day pickup changes (pgTAP). All people and data are invented.
begin;
select plan(10);

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

insert into public.pickup_overrides (family_id, day, pickup_time) values
  ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', '15:20'),
  ('00000000-0000-0000-0000-0000000000f1', '2026-12-04', null);

select throws_ok(
  $$insert into public.pickup_overrides (family_id, day, pickup_time)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', '16:00')$$,
  '23505', null, 'one change per day'
);
select is(
  (select count(*) from public.pickup_overrides where pickup_time is null), 1::bigint,
  'a day without pickup is stored as an empty time'
);
select ok(has_table_privilege('service_role', 'public.pickup_overrides', 'SELECT'), 'the Edge Function can read changes');
select ok(not has_table_privilege('anon', 'public.pickup_overrides', 'SELECT'), 'anon cannot read changes');

set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
select is((select count(*) from public.pickup_overrides), 2::bigint, 'family sees the changes of its own family');
select lives_ok(
  $$insert into public.pickup_overrides (family_id, day, pickup_time)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-05', '14:00')$$,
  'family can enter a change'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
select is((select count(*) from public.pickup_overrides), 0::bigint, 'a guest sees no changes');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a4","role":"authenticated"}', true);
select is((select count(*) from public.pickup_overrides), 0::bigint, 'another family sees no changes');
select throws_ok(
  $$insert into public.pickup_overrides (family_id, day, pickup_time)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-06', '14:00')$$,
  '42501', null, 'another family cannot enter a change'
);
select is(
  (select count(*) from public.pickup_overrides where family_id = '00000000-0000-0000-0000-0000000000f1'), 0::bigint,
  'another family cannot read them either'
);

select * from finish();
rollback;
