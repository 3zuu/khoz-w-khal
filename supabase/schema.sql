-- خذ و خل — Supabase schema. Run once in: Dashboard → SQL Editor.
create table public.categories(id uuid primary key default gen_random_uuid(), name text not null, icon text not null default '⭐', sort int not null default 0);
create table public.subcategories(id uuid primary key default gen_random_uuid(), category_id uuid not null references public.categories on delete cascade, name text not null, sort int not null default 0);
create table public.items(id uuid primary key default gen_random_uuid(), subcategory_id uuid not null references public.subcategories on delete cascade, name text not null, image_url text, created_at timestamptz not null default now());
create index on public.subcategories(category_id);
create index on public.items(subcategory_id);

-- Who may edit: only users listed here. No API policy exists on this table, so nobody can read or change it from the client.
create table public.admins(user_id uuid primary key references auth.users on delete cascade);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create function public.is_admin() returns boolean language sql security definer stable set search_path=public as
$$ select exists(select 1 from public.admins where user_id = auth.uid()) $$;

do $$ declare t text; begin
  foreach t in array array['categories','subcategories','items'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select to anon, authenticated using (true)', 'read_'||t, t);
    execute format('create policy %I on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', 'admin_write_'||t, t);
  end loop;
end $$;

-- Poster images: public read, admin-only write, max 1 MB, images only.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('posters','posters',true,1048576,array['image/jpeg','image/png','image/webp']) on conflict (id) do nothing;
create policy posters_admin_insert on storage.objects for insert to authenticated with check (bucket_id='posters' and public.is_admin());
create policy posters_admin_update on storage.objects for update to authenticated using (bucket_id='posters' and public.is_admin());
create policy posters_admin_delete on storage.objects for delete to authenticated using (bucket_id='posters' and public.is_admin());

-- AFTER creating your user in Dashboard → Authentication → Users, run this ONCE (use your own email; do not commit it anywhere):
-- insert into public.admins select id from auth.users where email = 'YOUR_EMAIL_HERE';
