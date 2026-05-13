-- Profiles table for Pick6
-- Mirrors the columns read/written by AuthManager.swift (loadProfile, saveProfile).

create table if not exists public.profiles (
    id              uuid primary key references auth.users(id) on delete cascade,
    first_name      text not null,
    last_name       text not null,
    whatsapp        text not null,
    date_of_birth   date not null,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- Row-level security: a user can only read/write their own row.
alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
    for select using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
    for insert with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
    for update using (auth.uid() = id) with check (auth.uid() = id);

-- Keep updated_at fresh on every update.
create or replace function public.profiles_set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
    before update on public.profiles
    for each row execute function public.profiles_set_updated_at();

-- Self-service account deletion (required for App Store guideline 5.1.1(v)).
-- security definer lets the function delete from auth.users as the function owner,
-- while auth.uid() pins it to the caller's own row.
create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        raise exception 'not authenticated';
    end if;
    delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_current_user() from public;
grant execute on function public.delete_current_user() to authenticated;
