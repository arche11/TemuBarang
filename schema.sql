-- TRACE database setup for Supabase (PostgreSQL)
-- Run the entire script in Supabase > SQL Editor > New query.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'New member',
  email text,
  role text not null default 'user' check (role in ('user','moderator','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('lost','found')),
  category text not null check (category in ('Electronics','Accessories','Documents','Bags','Other')),
  title text not null,
  location text not null,
  description text not null,
  image_url text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','returned')),
  created_at timestamptz not null default now()
);

create table if not exists public.saved_items (
  user_id uuid not null references public.profiles(id) on delete cascade,
  report_id uuid not null references public.reports(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, report_id)
);

create or replace function public.current_trace_role()
returns text language sql stable security definer set search_path = public
as $$ select coalesce((select role from public.profiles where id = auth.uid()), 'guest'); $$;

create or replace function public.is_trace_staff()
returns boolean language sql stable security definer set search_path = public
as $$ select public.current_trace_role() in ('admin','moderator'); $$;

-- Create a user profile automatically after signup.
create or replace function public.handle_new_trace_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id,name,email,role)
  values(new.id, coalesce(new.raw_user_meta_data->>'name','New member'), new.email, 'user')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_trace on auth.users;
create trigger on_auth_user_created_trace
after insert on auth.users
for each row execute procedure public.handle_new_trace_user();

-- Prevent users from changing their own role. Only an admin can change roles.
create or replace function public.prevent_self_role_change()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if old.role is distinct from new.role and auth.uid() = old.id
     and public.current_trace_role() <> 'admin' then
    raise exception 'You cannot change your own role';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_trace_role on public.profiles;
create trigger protect_trace_role before update on public.profiles
for each row execute procedure public.prevent_self_role_change();

alter table public.profiles enable row level security;
alter table public.reports enable row level security;
alter table public.saved_items enable row level security;

-- Profiles: users can read/update themselves; staff can read all; admins can update roles.
drop policy if exists "profile read self or staff" on public.profiles;
create policy "profile read self or staff" on public.profiles for select to authenticated
using (id = auth.uid() or public.is_trace_staff());
drop policy if exists "profile update self or admin" on public.profiles;
create policy "profile update self or admin" on public.profiles for update to authenticated
using (id = auth.uid() or public.current_trace_role() = 'admin')
with check (id = auth.uid() or public.current_trace_role() = 'admin');

-- Reports: everyone can see approved/returned reports; owners and staff can see their queues.
drop policy if exists "reports public approved" on public.reports;
create policy "reports public approved" on public.reports for select to anon, authenticated
using (status in ('approved','returned'));
drop policy if exists "reports owner or staff read" on public.reports;
create policy "reports owner or staff read" on public.reports for select to authenticated
using (user_id = auth.uid() or public.is_trace_staff());
drop policy if exists "reports authenticated insert own" on public.reports;
create policy "reports authenticated insert own" on public.reports for insert to authenticated
with check (user_id = auth.uid() and status = 'pending');
drop policy if exists "reports owner edit pending or staff" on public.reports;
create policy "reports owner edit pending or staff" on public.reports for update to authenticated
using ((user_id = auth.uid() and status = 'pending') or public.is_trace_staff())
with check ((user_id = auth.uid() and status = 'pending') or public.is_trace_staff());
drop policy if exists "reports owner delete pending or admin" on public.reports;
create policy "reports owner delete pending or admin" on public.reports for delete to authenticated
using ((user_id = auth.uid() and status = 'pending') or public.current_trace_role() = 'admin');

-- Saved items: each user controls only their own saved list.
drop policy if exists "saved items own access" on public.saved_items;
create policy "saved items own access" on public.saved_items for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

-- IMPORTANT: after signing up with your own account, promote it to admin manually
-- by running this query with the email you registered:
-- update public.profiles set role = 'admin' where email = 'YOUR_EMAIL@example.com';
