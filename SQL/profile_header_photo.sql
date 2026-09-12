-- Adds the profile header/cover photo column ProfileEditView's header
-- now supports editing, alongside the existing avatar. No migration
-- tooling wired up for this project, same as every other file in SQL/ —
-- paste this whole file into the Supabase SQL editor and run it once.

alter table profiles add column if not exists header_photo_url text;

-- Uploaded to the same "avatars" storage bucket as the avatar itself
-- (path "<user id>/header.jpg" vs. "<user id>/avatar.jpg") rather than a
-- separate bucket — that bucket's existing per-user-folder policies
-- already allow any filename under the owner's own folder, so no new
-- storage policy is needed here.
