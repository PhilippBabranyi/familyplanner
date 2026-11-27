-- Step 2 of "pickup per child": every pickup table belongs to a child (a person of the household with
-- has_pickup = true) instead of to the family as a whole. Several children each get their own pickup times,
-- drivers, changes for single days and reminders.
--
-- Existing data moves to the one child that is marked in household_people. If none or several are marked while
-- there is data, this migration stops with a message and changes nothing (it runs in one transaction).
--
-- The digest log keeps one entry per child for the pickup reminder: slot 'pickup:<child id>'.

do $$
declare
  fam record;
  kids int;
  has_data boolean;
begin
  for fam in select id from public.families loop
    select count(*) into kids from public.household_people where family_id = fam.id and has_pickup;
    select exists (select 1 from public.pickup_times where family_id = fam.id)
        or exists (select 1 from public.pickup_drivers where family_id = fam.id)
        or exists (select 1 from public.pickup_overrides where family_id = fam.id)
      into has_data;
    if has_data and kids <> 1 then
      raise exception
        'Family % has pickup data and % children marked. Run: update public.household_people set has_pickup = true where display_name = ''<name>''; (exactly one child) and try again.',
        fam.id, kids;
    end if;
  end loop;
end $$;

-- The child belongs to the same family as the row.
alter table public.pickup_times add column person_id uuid;
alter table public.pickup_drivers add column person_id uuid;
alter table public.pickup_overrides add column person_id uuid;

update public.pickup_times t set person_id = p.id
  from public.household_people p where p.family_id = t.family_id and p.has_pickup;
update public.pickup_drivers t set person_id = p.id
  from public.household_people p where p.family_id = t.family_id and p.has_pickup;
update public.pickup_overrides t set person_id = p.id
  from public.household_people p where p.family_id = t.family_id and p.has_pickup;

alter table public.pickup_times alter column person_id set not null;
alter table public.pickup_drivers alter column person_id set not null;
alter table public.pickup_overrides alter column person_id set not null;

alter table public.pickup_times drop constraint pickup_times_pkey;
alter table public.pickup_times add primary key (family_id, person_id, weekday);
alter table public.pickup_times add constraint pickup_times_person_fkey
  foreign key (family_id, person_id) references public.household_people (family_id, id) on delete cascade;

alter table public.pickup_drivers drop constraint pickup_drivers_pkey;
alter table public.pickup_drivers add primary key (family_id, person_id, day);
alter table public.pickup_drivers add constraint pickup_drivers_person_fkey
  foreign key (family_id, person_id) references public.household_people (family_id, id) on delete cascade;

alter table public.pickup_overrides drop constraint pickup_overrides_pkey;
alter table public.pickup_overrides add primary key (family_id, person_id, day);
alter table public.pickup_overrides add constraint pickup_overrides_person_fkey
  foreign key (family_id, person_id) references public.household_people (family_id, id) on delete cascade;

-- One reminder per child and day. Old rows ('pickup') are converted while no constraint is in place,
-- and the new constraint is added afterwards, otherwise existing rows would violate it.
alter table public.digest_log drop constraint digest_log_slot_check;
update public.digest_log l
  set slot = 'pickup:' || p.id
  from public.household_people p
  where l.slot = 'pickup' and p.family_id = l.family_id and p.has_pickup;
delete from public.digest_log where slot = 'pickup';
alter table public.digest_log
  add constraint digest_log_slot_check check (
    slot in ('morning', 'evening', 'leave')
    or slot ~ '^pickup:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  );
