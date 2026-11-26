-- The table household_people (20261127100000) was created without privileges for the app's role, so every
-- request that touched it failed with "permission denied". This project grants privileges explicitly.
-- Row-level security still decides who may do what: admin and family read, only an admin writes.

revoke all on public.household_people from anon, authenticated;
grant select, insert, update, delete on public.household_people to authenticated;
