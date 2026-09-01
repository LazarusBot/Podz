-- Resolves a username to its account email so the client can sign in
-- with either email or username, while still only ever calling Supabase
-- Auth's normal email/password sign-in under the hood.
--
-- `auth.users` (which holds email) isn't queryable by the anon/authenticated
-- roles for security reasons, and `public.profiles` doesn't store email —
-- so this is the one narrow, server-side bridge between the two: given a
-- username, return only that single matching email, nothing else from
-- either table. SECURITY DEFINER is what lets it read `auth.users` at all;
-- the fixed `search_path` keeps that elevated privilege from being hijacked
-- by a search-path injection.
--
-- Run this once in the Supabase SQL Editor (Dashboard → SQL Editor).
create or replace function public.get_email_for_username(p_username text)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select u.email
  from auth.users u
  join public.profiles p on p.id = u.id
  where lower(p.username) = lower(p_username)
  limit 1;
$$;

-- Callable pre-login (anon) and post-login (authenticated) — login itself
-- happens before a session exists, so anon access is required for the
-- login screen to use this at all.
revoke all on function public.get_email_for_username(text) from public;
grant execute on function public.get_email_for_username(text) to anon, authenticated;
