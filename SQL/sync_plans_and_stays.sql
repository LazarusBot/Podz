-- Saved plans and "how was your stay" answers, kept in the account so they
-- survive a reinstall and follow the traveler to a new phone. Both stay
-- local-first in the app (it works without any of this); this only adds the
-- copy. Paste the whole file into the Supabase SQL editor and run it once.
-- Every policy is "your own rows only": nothing here is readable by anyone else.

-- ---------------------------------------------------------------------------
-- Saved plans (Profile > Plans)
-- ---------------------------------------------------------------------------

create table if not exists saved_plans (
    id uuid primary key,
    user_id uuid not null references profiles(id) on delete cascade,
    title text not null check (char_length(title) <= 200),
    -- The plan as the app encodes it (huts, order, answers). Small on purpose.
    payload jsonb not null check (pg_column_size(payload) <= 20000),
    saved_at timestamptz not null default now()
);

create index if not exists saved_plans_user_idx on saved_plans (user_id);

alter table saved_plans enable row level security;

drop policy if exists "Users read their own saved plans" on saved_plans;
create policy "Users read their own saved plans" on saved_plans
    for select using (user_id = auth.uid());

drop policy if exists "Users insert their own saved plans" on saved_plans;
create policy "Users insert their own saved plans" on saved_plans
    for insert with check (user_id = auth.uid());

drop policy if exists "Users update their own saved plans" on saved_plans;
create policy "Users update their own saved plans" on saved_plans
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Users delete their own saved plans" on saved_plans;
create policy "Users delete their own saved plans" on saved_plans
    for delete using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- How a stay went (the question Lenny asks once a stay is over)
-- ---------------------------------------------------------------------------

create table if not exists stay_feedback (
    reservation_id uuid primary key references reservations(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    -- null = the question was skipped ("Not now"): it isn't asked twice.
    mood text check (mood in ('good', 'bad')),
    -- File names inside "<user id>/<reservation id>/" in the stay-photos bucket.
    photos text[] not null default '{}' check (coalesce(array_length(photos, 1), 0) <= 12),
    answered_at timestamptz not null default now()
);

create index if not exists stay_feedback_user_idx on stay_feedback (user_id);

alter table stay_feedback enable row level security;

drop policy if exists "Users read their own stay feedback" on stay_feedback;
create policy "Users read their own stay feedback" on stay_feedback
    for select using (user_id = auth.uid());

drop policy if exists "Users insert their own stay feedback" on stay_feedback;
create policy "Users insert their own stay feedback" on stay_feedback
    for insert with check (user_id = auth.uid());

drop policy if exists "Users update their own stay feedback" on stay_feedback;
create policy "Users update their own stay feedback" on stay_feedback
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Users delete their own stay feedback" on stay_feedback;
create policy "Users delete their own stay feedback" on stay_feedback
    for delete using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- The photos kept with a stay: a private bucket, one folder per user
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('stay-photos', 'stay-photos', false, 2000000, array['image/jpeg'])
on conflict (id) do update
    set public = false,
        file_size_limit = 2000000,
        allowed_mime_types = array['image/jpeg'];

-- A user only touches files under their own folder: "<their id>/...".
drop policy if exists "Users read their own stay photos" on storage.objects;
create policy "Users read their own stay photos" on storage.objects
    for select to authenticated
    using (bucket_id = 'stay-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users upload their own stay photos" on storage.objects;
create policy "Users upload their own stay photos" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'stay-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete their own stay photos" on storage.objects;
create policy "Users delete their own stay photos" on storage.objects
    for delete to authenticated
    using (bucket_id = 'stay-photos' and (storage.foldername(name))[1] = auth.uid()::text);
