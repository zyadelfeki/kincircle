-- Minimal KinCircle schema for Supabase/Postgres
-- Run in the Supabase SQL editor.

create extension if not exists pgcrypto;

-- Profiles (linked to auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  created_at timestamp with time zone default now()
);

alter table public.profiles enable row level security;
create policy "Read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Insert own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "Update own profile" on public.profiles for update using (auth.uid() = id);

-- Families
create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references auth.users(id),
  created_at timestamp with time zone default now()
);

alter table public.families enable row level security;
create policy "Members can read families" on public.families for select using (
  exists (select 1 from public.family_members m where m.family_id = families.id and m.user_id = auth.uid())
);
create policy "Owner can insert" on public.families for insert with check (owner_id = auth.uid());
create policy "Owner can update" on public.families for update using (owner_id = auth.uid());

-- Family members
create table if not exists public.family_members (
  family_id uuid references public.families(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text default 'member',
  primary key (family_id, user_id)
);

alter table public.family_members enable row level security;
create policy "User can see memberships" on public.family_members for select using (user_id = auth.uid());
create policy "Family owner can insert members" on public.family_members for insert with check (
  exists (select 1 from public.families f where f.id = family_members.family_id and f.owner_id = auth.uid())
);

-- Invites
create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  sender_id uuid not null references auth.users(id),
  recipient_email text not null,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamp with time zone default now()
);

alter table public.invites enable row level security;
-- Sender can manage their own invites
create policy "Sender can read invites" on public.invites for select using (sender_id = auth.uid());
create policy "Sender can create invites" on public.invites for insert with check (sender_id = auth.uid());
-- Recipient can read and delete their own invites (to allow decline)
create policy "Recipient can read invite" on public.invites for select using (recipient_email = auth.jwt() ->> 'email');
create policy "Recipient can delete invite" on public.invites for delete using (recipient_email = auth.jwt() ->> 'email');
-- Optionally, recipient can update status
create policy "Recipient can update invite" on public.invites for update using (recipient_email = auth.jwt() ->> 'email');

-- Helper: trigger to set sender_id from auth.uid() if not provided
create or replace function public.set_sender_id()
returns trigger language plpgsql as $$
begin
  if new.sender_id is null then
    new.sender_id := auth.uid();
  end if;
  return new;
end; $$;

drop trigger if exists trg_set_sender_id on public.invites;
create trigger trg_set_sender_id before insert on public.invites for each row execute function public.set_sender_id();
