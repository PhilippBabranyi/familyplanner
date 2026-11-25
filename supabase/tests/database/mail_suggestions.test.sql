-- Tests for mail suggestions and the AI context (pgTAP). All people and data are invented.
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

insert into public.mailboxes (id, family_id, owner_id, label, token_hash) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-0000000000a1', 'Alex', repeat('a', 64)),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000f2',
   '00000000-0000-0000-0000-0000000000a4', 'Stranger', repeat('b', 64));

insert into public.inbox_items
  (id, family_id, mailbox_id, gmail_message_id, gmail_thread_id, sender, subject, received_at, link,
   suggestion) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-0000000000c1', 'm1', 't1', 'teacher@school.example', 'Trip', now(),
   'https://mail.google.com/mail/u/0/#all/t1', '{"kind":"event","title":"Zoo trip"}'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000f2',
   '00000000-0000-0000-0000-0000000000c2', 'm2', 't2', 'someone@other.example', 'Other', now(),
   'https://mail.google.com/mail/u/0/#all/t2', null);

insert into public.mail_context (family_id, context) values
  ('00000000-0000-0000-0000-0000000000f1', 'Child Test goes to Example School, class Owls.'),
  ('00000000-0000-0000-0000-0000000000f2', 'Other family context.');

select is((select status from public.inbox_items where gmail_message_id = 'm1'), 'new',
  'new inbox items start with status new');

-- Family member (sam)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;

update public.inbox_items set status = 'accepted' where gmail_message_id = 'm1';
select is((select status from public.inbox_items where gmail_message_id = 'm1'), 'accepted',
  'a family member can set the status of an inbox item');

select throws_ok(
  $$update public.inbox_items set suggestion = '{"kind":"task"}' where gmail_message_id = 'm1'$$,
  '42501', null, 'a family member cannot change the suggestion itself'
);
select throws_ok(
  $$update public.inbox_items set status = 'archived' where gmail_message_id = 'm1'$$,
  '23514', null, 'only the known status values are allowed'
);

update public.inbox_items set status = 'dismissed' where gmail_message_id = 'm2';
select is((select count(*)::int from public.mail_context), 1, 'a family member sees only the own family context');

update public.mail_context set context = 'Updated context.' where family_id = '00000000-0000-0000-0000-0000000000f1';
select is((select context from public.mail_context), 'Updated context.', 'a family member can edit the context');
reset role;

select is((select status from public.inbox_items where gmail_message_id = 'm2'), 'new',
  'a family member cannot change items of another family');

-- Guest (helper)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.mail_context), 0, 'a guest sees no context');
update public.mail_context set context = 'Guest edit' where family_id = '00000000-0000-0000-0000-0000000000f1';
reset role;
select is((select context from public.mail_context where family_id = '00000000-0000-0000-0000-0000000000f1'),
  'Updated context.', 'a guest cannot change the context');

-- Anonymous
set local role anon;
select throws_ok('select * from public.mail_context', '42501', null, 'anon cannot read the context');
reset role;

-- The Edge Function runs as service_role.
select ok(
  has_table_privilege('service_role', 'public.mail_context', 'SELECT')
  and has_table_privilege('service_role', 'public.inbox_items', 'UPDATE'),
  'service_role can read the context and write inbox items'
);

select * from finish();
rollback;
