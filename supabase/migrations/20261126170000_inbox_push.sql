-- Bell and push notifications for mail suggestions.
-- - tasks get an optional cash amount (like calendar items already have)
-- - device_tokens: the push addresses of the family's phones, written only through register_device()

alter table public.tasks
  add column cash_cents integer check (cash_cents is null or cash_cents >= 0);

create table public.device_tokens (
  token text primary key check (length(token) between 32 and 200),
  family_id uuid not null,
  user_id uuid not null,
  created_at timestamptz not null default now(),
  foreign key (family_id, user_id)
    references public.family_members (family_id, user_id) on delete cascade
);

create index device_tokens_family_id_idx on public.device_tokens (family_id);

alter table public.device_tokens enable row level security;

-- Nobody reads or writes tokens directly through the API; the app uses register_device() and the
-- Edge Function (service_role) reads them to send pushes.
revoke all on public.device_tokens from anon, authenticated;
grant select, delete on public.device_tokens to service_role;

-- SECURITY DEFINER: lets a phone take over a token that belonged to another account on the same device.
create function public.register_device(device_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  member_family uuid;
begin
  select m.family_id into member_family
  from public.family_members m
  where m.user_id = auth.uid() and m.role in ('admin', 'family')
  limit 1;

  if member_family is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  insert into public.device_tokens (token, family_id, user_id)
  values (device_token, member_family, auth.uid())
  on conflict (token) do update
    set family_id = excluded.family_id, user_id = excluded.user_id;
end;
$$;

revoke all on function public.register_device(text) from public, anon;
grant execute on function public.register_device(text) to authenticated;
