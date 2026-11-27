-- Tests for the "take along" notes (pgTAP). All people and data are invented.
begin;
select plan(12);

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

insert into public.household_people (id, family_id, display_name, has_pickup) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1', 'Kim', true);

insert into public.pickup_notes (family_id, person_id, weekday, valid_from, note) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 3, '2026-09-01', 'Book back'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 3, '2027-01-11', '');

select throws_ok(
  $$insert into public.pickup_notes (family_id, person_id, weekday, valid_from, note)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 3, '2026-09-01', 'Again')$$,
  '23505', null, 'one note per weekday and start day'
);
select throws_ok(
  $$insert into public.pickup_notes (family_id, person_id, weekday, valid_from, note)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 8, '2026-09-01', 'x')$$,
  '23514', null, 'the weekday must be 1 to 7'
);
select throws_ok(
  format($$insert into public.pickup_notes (family_id, person_id, weekday, valid_from, note)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 4, '2026-09-01', %L)$$, repeat('x', 201)),
  '23514', null, 'a note is at most 200 characters'
);
select is(
  (select note from public.pickup_notes
    where weekday = 3 and valid_from <= '2026-12-02' order by valid_from desc limit 1), 'Book back',
  'before the new rhythm starts the old note counts'
);
select is(
  (select note from public.pickup_notes
    where weekday = 3 and valid_from <= '2027-01-13' order by valid_from desc limit 1), '',
  'from the new rhythm on an empty note means nothing to take along'
);
select ok(has_table_privilege('service_role', 'public.pickup_notes', 'SELECT'), 'the Edge Function can read notes');
select ok(not has_table_privilege('anon', 'public.pickup_notes', 'SELECT'), 'anon cannot read notes');

set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
select lives_ok(
  $$insert into public.pickup_note_overrides (family_id, person_id, day, note)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', '2026-12-02', 'Swimming kit')$$,
  'family can set a note for one day'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
select is((select count(*) from public.pickup_notes), 0::bigint, 'a guest sees no notes');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a4","role":"authenticated"}', true);
select is(
  (select count(*) from public.pickup_notes) + (select count(*) from public.pickup_note_overrides), 0::bigint,
  'another family sees no notes'
);
select throws_ok(
  $$insert into public.pickup_notes (family_id, person_id, weekday, valid_from, note)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 5, '2026-12-01', 'Piano book')$$,
  '42501', null, 'another family cannot enter notes'
);
select throws_ok(
  $$insert into public.pickup_note_overrides (family_id, person_id, day, note)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', '2026-12-03', 'x')$$,
  '42501', null, 'another family cannot enter a note for a day'
);

select * from finish();
rollback;
