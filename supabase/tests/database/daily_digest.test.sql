-- Tests for the digest log and the privileges of the Edge Function (pgTAP). All data is invented.
begin;
select plan(8);

insert into public.families (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Test Family');

select ok(has_table_privilege('service_role', 'public.digest_log', 'INSERT'), 'service_role can reserve a slot');
select ok(has_table_privilege('service_role', 'public.digest_log', 'DELETE'), 'service_role can release a slot');
select ok(
  has_table_privilege('service_role', 'public.calendar_items', 'SELECT')
  and has_table_privilege('service_role', 'public.tasks', 'SELECT')
  and has_table_privilege('service_role', 'public.household_people', 'SELECT')
  and has_table_privilege('service_role', 'public.family_members', 'SELECT'),
  'service_role can read what the digest is made of'
);
select ok(not has_table_privilege('authenticated', 'public.digest_log', 'SELECT'), 'the app cannot read the log');
select ok(not has_table_privilege('anon', 'public.digest_log', 'SELECT'), 'anon cannot read the log');

insert into public.digest_log (family_id, day, slot) values ('00000000-0000-0000-0000-0000000000f1', '2026-12-01', 'morning');
select throws_ok(
  $$insert into public.digest_log (family_id, day, slot)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-01', 'morning')$$,
  '23505', null, 'a slot can only be sent once per day'
);
select lives_ok(
  $$insert into public.digest_log (family_id, day, slot)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-01', 'evening')$$,
  'the evening is a separate slot'
);
select throws_ok(
  $$insert into public.digest_log (family_id, day, slot)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-01', 'noon')$$,
  '23514', null, 'only known slots are allowed'
);

select * from finish();
rollback;
