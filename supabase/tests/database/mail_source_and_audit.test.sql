-- Tests for who created an entry and where it came from (pgTAP). All people and data are invented.
begin;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'alex@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'sam@example.test');

insert into public.families (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Test Family');

insert into public.family_members (family_id, user_id, display_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Alex', 'admin'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a2', 'Sam', 'family');

insert into public.mailboxes (id, family_id, owner_id, label, token_hash) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-0000000000a1', 'Test box', repeat('a', 64));
insert into public.inbox_items (id, family_id, mailbox_id, gmail_message_id, gmail_thread_id, sender, subject, received_at, link)
values (
  '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1',
  '00000000-0000-0000-0000-0000000000b1', 'm1', 't1', 'School <school@example.test>', 'Science Fair',
  '2026-11-27 10:00+00', 'https://mail.google.com/mail/#all/t1'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);

-- The creator is set by the database, whatever the app sends.
insert into public.tasks (family_id, title, created_by)
values ('00000000-0000-0000-0000-0000000000f1', 'Pretend to be Alex', '00000000-0000-0000-0000-0000000000a1');
select is(
  (select created_by from public.tasks where title = 'Pretend to be Alex'),
  '00000000-0000-0000-0000-0000000000a2'::uuid, 'a task records the signed-in user, not a claimed one'
);
insert into public.calendar_items (family_id, title, starts_on)
values ('00000000-0000-0000-0000-0000000000f1', 'Dentist', '2026-12-03');
select is(
  (select created_by from public.calendar_items where title = 'Dentist'),
  '00000000-0000-0000-0000-0000000000a2'::uuid, 'a calendar item records the signed-in user'
);

-- The reference to the mail is stored with the entry.
insert into public.calendar_items (
  family_id, title, starts_on, source_inbox_item, source_sender, source_subject, source_link
) values (
  '00000000-0000-0000-0000-0000000000f1', 'Primary Science Fair', '2026-12-04',
  '00000000-0000-0000-0000-0000000000c1', 'School <school@example.test>', 'Science Fair',
  'https://mail.google.com/mail/#all/t1'
);
select is(
  (select source_subject from public.calendar_items where title = 'Primary Science Fair'),
  'Science Fair', 'an entry from a mail keeps the subject'
);
select is(
  (select source_subject from public.calendar_items where title = 'Dentist'), null,
  'an entry made by hand has no mail reference'
);
select throws_ok(
  $$insert into public.tasks (family_id, title, source_link)
    values ('00000000-0000-0000-0000-0000000000f1', 'Bad link', 'https://evil.example.test/x')$$,
  '23514', null, 'the link must lead to Gmail'
);
select throws_ok(
  $$insert into public.tasks (family_id, title, source_subject)
    values ('00000000-0000-0000-0000-0000000000f1', 'Long subject', repeat('x', 501))$$,
  '23514', null, 'the subject has a length limit'
);

-- Who decided a suggestion, and when.
select is(
  (select decided_by from public.inbox_items where id = '00000000-0000-0000-0000-0000000000c1'), null,
  'an open suggestion has no decision yet'
);
update public.inbox_items set status = 'accepted' where id = '00000000-0000-0000-0000-0000000000c1';
select is(
  (select decided_by from public.inbox_items where id = '00000000-0000-0000-0000-0000000000c1'),
  '00000000-0000-0000-0000-0000000000a2'::uuid, 'accepting records who did it'
);
select ok(
  (select decided_at is not null from public.inbox_items where id = '00000000-0000-0000-0000-0000000000c1'),
  'accepting records when'
);

-- The reference survives the nightly cleanup of the inbox.
reset role;
delete from public.inbox_items where id = '00000000-0000-0000-0000-0000000000c1';
select is(
  (select source_inbox_item from public.calendar_items where title = 'Primary Science Fair'), null,
  'deleting the suggestion unlinks the entry'
);
select is(
  (select source_subject from public.calendar_items where title = 'Primary Science Fair'), 'Science Fair',
  'but the entry still names the mail'
);
select is(
  (select source_sender from public.calendar_items where title = 'Primary Science Fair'),
  'School <school@example.test>', 'and the sender'
);

-- Calls without a user (Edge Functions) keep what they send. The test connection is no longer signed in.
select set_config('request.jwt.claims', '', true);
insert into public.tasks (family_id, title, created_by)
values ('00000000-0000-0000-0000-0000000000f1', 'From a function', '00000000-0000-0000-0000-0000000000a1');
select is(
  (select created_by from public.tasks where title = 'From a function'),
  '00000000-0000-0000-0000-0000000000a1'::uuid, 'service calls can name the creator'
);

select * from finish();
rollback;
