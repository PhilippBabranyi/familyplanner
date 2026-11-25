-- Row-level security tests for the mail intake tables (pgTAP). All people and data are invented.
begin;
select plan(18);

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

insert into public.mail_filters (family_id, mailbox_id, kind, value) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 'sender', 'school.example'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000c2', 'sender', 'other.example');

insert into public.inbox_items
  (family_id, mailbox_id, gmail_message_id, gmail_thread_id, sender, subject, received_at, link) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 'm1', 't1',
   'teacher@school.example', 'Trip', now(), 'https://mail.google.com/mail/u/0/#all/t1'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000c2', 'm2', 't2',
   'someone@other.example', 'Other', now(), 'https://mail.google.com/mail/u/0/#all/t2');

-- Constraints
select throws_ok(
  $$insert into public.mailboxes (family_id, owner_id, label, token_hash)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a2', 'Bad', 'secret')$$,
  '23514', null, 'the token must be stored as a sha-256 hash'
);
select throws_ok(
  $$insert into public.mailboxes (family_id, owner_id, label, token_hash)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a4', 'Outsider', repeat('c', 64))$$,
  '23503', null, 'a mailbox owner must be a member of the family'
);
select throws_ok(
  $$insert into public.mail_filters (family_id, mailbox_id, kind, value)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 'subject', 'invoice')$$,
  '23514', null, 'filter kinds are limited to sender and keyword'
);

-- Anonymous
set local role anon;
select throws_ok('select * from public.mailboxes', '42501', null, 'anon cannot read mailboxes');
reset role;

-- Family member (sam)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.mailboxes), 1, 'family member sees the mailboxes of their family only');
select throws_ok('select token_hash from public.mailboxes', '42501', null, 'the token hash is not readable');
select throws_ok(
  $$insert into public.mailboxes (family_id, owner_id, label, token_hash)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a2', 'Own', repeat('d', 64))$$,
  '42501', null, 'mailboxes cannot be created through the API'
);
select is((select count(*)::int from public.mail_filters), 1, 'family member sees the filters of their family only');
select lives_ok(
  $$insert into public.mail_filters (family_id, mailbox_id, kind, value)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 'keyword', 'Bescheid')$$,
  'family member can add a filter'
);
select throws_ok(
  $$insert into public.mail_filters (family_id, mailbox_id, kind, value)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 'sender', 'SCHOOL.example')$$,
  '23505', null, 'the same filter cannot be added twice, ignoring case'
);
select throws_ok(
  $$insert into public.mail_filters (family_id, mailbox_id, kind, value)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c2', 'sender', 'sneaky.example')$$,
  '23503', null, 'a filter cannot point at a mailbox of another family'
);
select throws_ok(
  $$insert into public.mail_filters (family_id, mailbox_id, kind, value)
    values ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000c2', 'sender', 'sneaky.example')$$,
  '42501', null, 'family member cannot add filters to another family'
);
select is((select count(*)::int from public.inbox_items), 1, 'family member sees the inbox of their family only');
select throws_ok(
  $$insert into public.inbox_items (family_id, mailbox_id, gmail_message_id, gmail_thread_id, sender, subject, received_at, link)
    values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 'm9', 't9',
            'x@school.example', 'Fake', now(), 'https://mail.google.com/mail/u/0/#all/t9')$$,
  '42501', null, 'inbox items cannot be created through the API'
);
select lives_ok(
  $$delete from public.inbox_items where gmail_message_id = 'm1'$$,
  'family member can remove an inbox item'
);
select is((select count(*)::int from public.inbox_items), 0, 'the removed inbox item is gone');
reset role;

-- Guest (helper)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select is(
  (select count(*)::int from public.mailboxes)
  + (select count(*)::int from public.mail_filters)
  + (select count(*)::int from public.inbox_items),
  0, 'guest sees no mailboxes, filters or inbox items'
);
reset role;

-- The Edge Function runs as service_role and must reach the intake tables.
select ok(
  has_table_privilege('service_role', 'public.mailboxes', 'SELECT')
  and has_table_privilege('service_role', 'public.mail_filters', 'SELECT')
  and has_table_privilege('service_role', 'public.inbox_items', 'INSERT'),
  'service_role can use the intake tables'
);

select * from finish();
rollback;
