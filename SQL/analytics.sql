-- First-party usage events and crash reports (Podz/Analytics).
-- Run once in the Supabase SQL editor. The app can only INSERT: nobody can
-- read these rows through the API, only you in the dashboard (service role).

create table if not exists public.app_events (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  occurred_at  timestamptz not null,
  install_id   uuid        not null,
  session_id   uuid        not null,
  name         text        not null,
  props        jsonb       not null default '{}',
  app_version  text,
  build        text,
  os           text,
  locale       text,
  is_debug     boolean     not null default false
);

create index if not exists app_events_name_time on public.app_events (name, occurred_at desc);
create index if not exists app_events_install on public.app_events (install_id, occurred_at desc);

create table if not exists public.app_diagnostics (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  install_id  uuid        not null,
  app_version text,
  build       text,
  os          text,
  summary     text,
  payload     text
);

alter table public.app_events enable row level security;
alter table public.app_diagnostics enable row level security;

drop policy if exists "app can insert events" on public.app_events;
create policy "app can insert events" on public.app_events
  for insert to anon, authenticated with check (true);

drop policy if exists "app can insert diagnostics" on public.app_diagnostics;
create policy "app can insert diagnostics" on public.app_diagnostics
  for insert to anon, authenticated with check (true);

-- Handy views for the dashboard.
-- Where people drop off, per day (release builds only):
create or replace view public.app_funnel with (security_invoker = true) as
select date_trunc('day', occurred_at) as day,
       count(distinct install_id) filter (where name = 'app_open')            as opened,
       count(distinct install_id) filter (where name = 'pod_opened')          as opened_a_pod,
       count(distinct install_id) filter (where name = 'book_tapped'
                                            or name = 'hut_contact_tapped')   as wanted_to_book,
       count(distinct install_id) filter (where name = 'reservation_booked')  as booked
from public.app_events
where not is_debug
group by 1
order by 1 desc;
