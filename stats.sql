-- خذ و خل — Anonymous decision stats ("78% left this"). Run ONCE in SQL Editor (after schema.sql). Safe to re-run.
-- Stores only two counters per item. No IP, no user id, no timestamps.
create table if not exists public.item_stats(
  item_id uuid primary key references public.items on delete cascade,
  takes int not null default 0,
  leaves int not null default 0
);
alter table public.item_stats enable row level security;
revoke all on public.item_stats from anon, authenticated;   -- reachable only through record_decision()

create or replace function public.record_decision(p_item uuid, p_take boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare t int; l int;
begin
  if not exists (select 1 from public.items where id = p_item) then return null; end if;
  select takes, leaves into t, l from public.item_stats where item_id = p_item;
  insert into public.item_stats(item_id, takes, leaves)
  values (p_item, case when p_take then 1 else 0 end, case when p_take then 0 else 1 end)
  on conflict (item_id) do update
    set takes  = public.item_stats.takes  + case when p_take then 1 else 0 end,
        leaves = public.item_stats.leaves + case when p_take then 0 else 1 end;
  return jsonb_build_object('takes', coalesce(t, 0), 'leaves', coalesce(l, 0));  -- counts BEFORE this decision
end $$;
revoke all on function public.record_decision(uuid, boolean) from public;
grant execute on function public.record_decision(uuid, boolean) to anon, authenticated;

-- Optional: wipe stats (e.g. after testing):  truncate public.item_stats;
