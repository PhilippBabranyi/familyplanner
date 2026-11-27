-- Tests for the pickup per child (pgTAP). All people and data are invented.
begin;
select plan(9);

insert into public.families (id, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'Test Family'),
  ('00000000-0000-0000-0000-0000000000f2', 'Other Family');

insert into public.household_people (id, family_id, display_name, has_pickup) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1', 'Kim', true),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000f1', 'Robin', true),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000f1', 'Helper', false),
  ('00000000-0000-0000-0000-0000000000c4', '00000000-0000-0000-0000-0000000000f2', 'Other', true);

select is(
  (select has_pickup from public.household_people where display_name = 'Helper'), false,
  'a person has no pickup unless marked'
);

-- Two children can have a pickup on the same weekday.
insert into public.pickup_times (family_id, person_id, weekday, pickup_time) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 4, '16:20'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c2', 4, '15:30');
select is((select count(*) from public.pickup_times), 2::bigint, 'each child has a pickup time of their own');

select throws_ok(
  $$insert into public.pickup_times (family_id, person_id, weekday, pickup_time)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 4, '17:00')$$,
  '23505', null, 'one time per child and weekday'
);
select throws_ok(
  $$insert into public.pickup_times (family_id, person_id, weekday, pickup_time)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c4', 5, '17:00')$$,
  '23503', null, 'a child of another family cannot be used'
);
select throws_ok(
  $$insert into public.pickup_overrides (family_id, person_id, day, pickup_time)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c4', '2026-12-03', null)$$,
  '23503', null, 'the same holds for changes of single days'
);

-- The digest log keeps one reminder per child and day.
insert into public.digest_log (family_id, day, slot) values
  ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', 'pickup:00000000-0000-0000-0000-0000000000c1');
select lives_ok(
  $$insert into public.digest_log (family_id, day, slot)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', 'pickup:00000000-0000-0000-0000-0000000000c2')$$,
  'every child has their own reminder'
);
select throws_ok(
  $$insert into public.digest_log (family_id, day, slot)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', 'pickup:00000000-0000-0000-0000-0000000000c1')$$,
  '23505', null, 'but only one per day'
);
select throws_ok(
  $$insert into public.digest_log (family_id, day, slot)
    values ('00000000-0000-0000-0000-0000000000f1', '2026-12-03', 'pickup')$$,
  '23514', null, 'the pickup reminder always names the child'
);

-- Removing a child removes their pickup data.
delete from public.household_people where id = '00000000-0000-0000-0000-0000000000c2';
select is((select count(*) from public.pickup_times), 1::bigint, 'a removed child takes their pickup times along');

select * from finish();
rollback;
