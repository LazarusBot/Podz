-- Photos taken from Wikimedia Commons need their credit (author and licence)
-- shown with them. Paste into the Supabase SQL editor and run once, before the
-- photo files that tools/fetch_hut_photos.py writes.

alter table pod_photos add column if not exists credit text;
alter table pod_photos add column if not exists source_url text;
