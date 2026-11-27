-- Step 1 of "pickup per child": marks which people of the household have a pickup.
--
-- Run this first, then mark the child(ren) in the SQL editor (once, with the real name, which is not part of the
-- repository):
--
--   update public.household_people set has_pickup = true where display_name = '<name of the child>';
--
-- Only then run the next migration (20261127215000_pickup_per_child.sql), which assigns the existing pickup data
-- to that child.

alter table public.household_people
  add column has_pickup boolean not null default false;
