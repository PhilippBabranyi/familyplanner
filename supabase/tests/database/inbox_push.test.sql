-- Tests for push device tokens and the task cash column (pgTAP). All people and data are invented.
begin;
select plan(9);

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

-- Family member (alex) registers a phone
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$select public.register_device(repeat('a', 64))$$, 'a family member can register a device');
select throws_ok('select * from public.device_tokens', '42501', null, 'tokens cannot be read through the API');
select throws_ok(
  $$insert into public.device_tokens (token, family_id, user_id)
    values (repeat('b', 64), '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1')$$,
  '42501', null, 'tokens cannot be written directly'
);
reset role;

select is((select family_id from public.device_tokens where token = repeat('a', 64)),
  '00000000-0000-0000-0000-0000000000f1'::uuid, 'the token is stored for the family of the caller');

-- The same phone is used by sam: the token moves to sam
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$select public.register_device(repeat('a', 64))$$, 'a token can be taken over by another family member');
reset role;
select is((select user_id from public.device_tokens where token = repeat('a', 64)),
  '00000000-0000-0000-0000-0000000000a2'::uuid, 'the token now belongs to the new user');

-- Guest and stranger
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select public.register_device(repeat('c', 64))$$, '42501', null, 'a guest cannot register a device');
reset role;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a4","role":"authenticated"}', true);
set local role anon;
select throws_ok($$select public.register_device(repeat('d', 64))$$, '42501', null, 'anon cannot register a device');
reset role;

-- The Edge Function runs as service_role
select ok(
  has_table_privilege('service_role', 'public.device_tokens', 'SELECT')
  and has_column_privilege('service_role', 'public.inbox_items', 'notified_at', 'UPDATE'),
  'service_role can read tokens and mark items as notified'
);

select * from finish();
rollback;
