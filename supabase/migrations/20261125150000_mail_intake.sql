-- Mail intake: mailboxes of family members, their sender/keyword filters, and the mails found.
--
-- A small script in each person's own Google account (see integrations/gmail-apps-script) sends
-- metadata of matching mails to the Edge Function `mail-intake`. The function uses a secret token per
-- mailbox; only the SHA-256 hash of that token is stored here and it is never readable through the API.
--
-- Mailboxes are created by the project owner in the SQL Editor (no insert policy for clients).
-- Filters are maintained by admin and family. Mails (inbox_items) are written only by the Edge Function.

create table public.mailboxes (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  owner_id uuid not null,
  label text not null check (length(trim(label)) > 0),
  -- SHA-256 of the secret token, as 64 lowercase hex characters.
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  unique (family_id, id),
  foreign key (family_id, owner_id)
    references public.family_members (family_id, user_id) on delete cascade
);

create table public.mail_filters (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  mailbox_id uuid not null,
  kind text not null check (kind in ('sender', 'keyword')),
  value text not null check (length(trim(value)) between 2 and 200),
  created_at timestamptz not null default now(),
  foreign key (family_id, mailbox_id)
    references public.mailboxes (family_id, id) on delete cascade
);

create unique index mail_filters_unique_idx
  on public.mail_filters (mailbox_id, kind, lower(trim(value)));

create table public.inbox_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  mailbox_id uuid not null,
  gmail_message_id text not null check (length(gmail_message_id) between 1 and 100),
  gmail_thread_id text not null check (length(gmail_thread_id) between 1 and 100),
  sender text not null check (length(sender) <= 300),
  subject text not null check (length(subject) <= 500),
  received_at timestamptz not null,
  -- Link back to the mail in Gmail. The mail text itself is not stored.
  link text not null check (link like 'https://mail.google.com/%'),
  created_at timestamptz not null default now(),
  unique (mailbox_id, gmail_message_id),
  foreign key (family_id, mailbox_id)
    references public.mailboxes (family_id, id) on delete cascade
);

create index mail_filters_family_id_idx on public.mail_filters (family_id);
create index inbox_items_family_id_idx on public.inbox_items (family_id, received_at desc);

alter table public.mailboxes enable row level security;
alter table public.mail_filters enable row level security;
alter table public.inbox_items enable row level security;

-- Mailboxes: admin and family can see them (without the token hash); nobody writes through the API.
create policy mailboxes_select on public.mailboxes
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

create policy filters_select on public.mail_filters
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy filters_insert on public.mail_filters
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy filters_update on public.mail_filters
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy filters_delete on public.mail_filters
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

-- Inbox items: readable and deletable by admin and family; inserted only by the Edge Function.
create policy inbox_select on public.inbox_items
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy inbox_delete on public.inbox_items
  for delete to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));

revoke all on public.mailboxes, public.mail_filters, public.inbox_items from anon, authenticated;
-- Column grant on purpose: token_hash is not readable through the API.
grant select (id, family_id, owner_id, label, last_seen_at, created_at) on public.mailboxes to authenticated;
grant select, insert, update, delete on public.mail_filters to authenticated;
grant select, delete on public.inbox_items to authenticated;
