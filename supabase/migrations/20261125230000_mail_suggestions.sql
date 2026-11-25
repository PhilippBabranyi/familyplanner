-- Mail suggestions: the Edge Function analyzes each mail with an AI model and stores only the suggestion
-- (never the mail text). Family members review the suggestions and mark them accepted or dismissed.
-- Also adds a free-text family context that is given to the model (kept in the database, not in the repo).

alter table public.inbox_items
  add column suggestion jsonb,
  add column status text not null default 'new' check (status in ('new', 'accepted', 'dismissed')),
  add column analyzed_at timestamptz;

create table public.mail_context (
  family_id uuid primary key references public.families (id) on delete cascade,
  -- Short background for the AI, e.g. which children go to which school. Plain text, written by the family.
  context text not null check (length(context) <= 4000),
  updated_at timestamptz not null default now()
);

alter table public.mail_context enable row level security;

create policy mail_context_select on public.mail_context
  for select to authenticated
  using (private.family_role(family_id) in ('admin', 'family'));
create policy mail_context_insert on public.mail_context
  for insert to authenticated
  with check (private.family_role(family_id) in ('admin', 'family'));
create policy mail_context_update on public.mail_context
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));

-- Members may change only the review status of an inbox item, nothing else.
create policy inbox_update on public.inbox_items
  for update to authenticated
  using (private.family_role(family_id) in ('admin', 'family'))
  with check (private.family_role(family_id) in ('admin', 'family'));

revoke all on public.mail_context from anon, authenticated;
grant select, insert, update on public.mail_context to authenticated;
grant update (status) on public.inbox_items to authenticated;

-- The Edge Function runs as service_role (bypasses RLS, but still needs table grants).
grant select on public.mail_context to service_role;
grant select, insert, update, delete on public.mailboxes, public.mail_filters, public.inbox_items to service_role;
