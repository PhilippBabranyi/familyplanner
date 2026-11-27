# Where does an entry come from?

Tasks and calendar items created from a mail suggestion keep a reference to the mail
(`source_sender`, `source_subject`, `source_link`, `source_inbox_item`). The forms show it
under "Aus einer Mail". Every new task and item also records who created it (`created_by`),
and every decision on a suggestion records who made it and when (`inbox_items.decided_by`,
`decided_at`). Both are stamped by database triggers from the signed-in user, so the app
cannot forge them.

Entries created before the migration have no such data.

## Audit queries (SQL editor)

Who accepted a suggestion, and when:

```sql
select i.subject, i.status, p.display_name as decided_by, i.decided_at
from public.inbox_items i
left join public.family_members p on p.user_id = i.decided_by
where i.subject ilike '%science fair%'
order by i.received_at desc;
```

Everything that came from a mail, with its creator:

```sql
select e.kind, e.title, e.source_sender, e.source_subject, m.display_name as created_by, e.created_at
from (
  select 'event' as kind, title, source_sender, source_subject, created_by, created_at
  from public.calendar_items where source_sender is not null
  union all
  select 'task', title, source_sender, source_subject, created_by, created_at
  from public.tasks where source_sender is not null
) e
left join public.family_members m on m.user_id = e.created_by
order by e.created_at desc;
```
