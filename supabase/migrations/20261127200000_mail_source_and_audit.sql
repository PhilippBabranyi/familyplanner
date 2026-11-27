-- Traceability: who created an entry and where it came from.
--
-- - tasks and calendar_items remember who created them (created_by, set by the database from the signed-in
--   user, the app cannot choose it) and, if the entry came from a mail suggestion, the mail it came from:
--   sender, subject, link and the inbox item. Sender and subject are copied, so that the reference survives
--   when the inbox item is deleted by the nightly cleanup.
-- - inbox_items remember who accepted or dismissed a suggestion and when (decided_by, decided_at), also set
--   by the database.

alter table public.tasks
  add column created_by uuid,
  add column source_inbox_item uuid references public.inbox_items (id) on delete set null,
  add column source_sender text check (length(source_sender) <= 300),
  add column source_subject text check (length(source_subject) <= 500),
  add column source_link text check (source_link like 'https://mail.google.com/%' and length(source_link) <= 500);

alter table public.calendar_items
  add column created_by uuid,
  add column source_inbox_item uuid references public.inbox_items (id) on delete set null,
  add column source_sender text check (length(source_sender) <= 300),
  add column source_subject text check (length(source_subject) <= 500),
  add column source_link text check (source_link like 'https://mail.google.com/%' and length(source_link) <= 500);

alter table public.inbox_items
  add column decided_by uuid,
  add column decided_at timestamptz;

-- A signed-in user cannot claim to be somebody else. Calls without a user (the Edge Functions with the
-- service role) keep what they send.
create function private.stamp_created_by()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;

create trigger tasks_stamp_created_by
  before insert on public.tasks
  for each row execute function private.stamp_created_by();
create trigger calendar_items_stamp_created_by
  before insert on public.calendar_items
  for each row execute function private.stamp_created_by();

create function private.stamp_decision()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null and new.status is distinct from old.status then
    new.decided_by := auth.uid();
    new.decided_at := now();
  end if;
  return new;
end;
$$;

create trigger inbox_items_stamp_decision
  before update on public.inbox_items
  for each row execute function private.stamp_decision();
