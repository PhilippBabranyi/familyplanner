-- Daily digest push: which slot (morning or evening) has been sent on which day, so that each is sent once.
-- Only the Edge Function (service_role) touches this table. The function also reads the family's calendar,
-- tasks and people to compose the message; this project grants privileges explicitly, so they are granted here.

create table public.digest_log (
  family_id uuid not null references public.families (id) on delete cascade,
  day date not null,
  slot text not null check (slot in ('morning', 'evening')),
  sent_at timestamptz not null default now(),
  primary key (family_id, day, slot)
);

alter table public.digest_log enable row level security;
revoke all on public.digest_log from anon, authenticated;
grant select, insert, delete on public.digest_log to service_role;

grant select on
  public.families,
  public.family_members,
  public.household_people,
  public.calendar_items,
  public.pickup_times,
  public.holidays,
  public.tasks
to service_role;
