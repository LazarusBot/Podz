-- Friend posts feed: post about a pod (text + photos), with likes and
-- comments, visible to the author and their accepted friends.
--
-- No migration tooling is wired up for this project (profiles,
-- friendships, messages, pod_likes, etc. were all created directly in the
-- Supabase SQL editor) — paste this whole file into the SQL editor and run
-- it once.

create table if not exists posts (
    id uuid primary key default gen_random_uuid(),
    author_id uuid not null references profiles(id) on delete cascade,
    pod_id uuid not null references pods(id) on delete cascade,
    body text,
    created_at timestamptz not null default now()
);

create table if not exists post_photos (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references posts(id) on delete cascade,
    url text not null,
    position int not null default 0
);

create table if not exists post_likes (
    post_id uuid not null references posts(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (post_id, user_id)
);

create table if not exists post_comments (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references posts(id) on delete cascade,
    author_id uuid not null references profiles(id) on delete cascade,
    body text not null,
    created_at timestamptz not null default now()
);

alter table posts enable row level security;
alter table post_photos enable row level security;
alter table post_likes enable row level security;
alter table post_comments enable row level security;

-- posts: visible to the author, or to an accepted friend of the author.
create policy "Author or friends can view posts" on posts
    for select using (
        author_id = auth.uid()
        or exists (
            select 1 from friendships f
            where f.status = 'accepted'
              and ((f.requester_id = auth.uid() and f.addressee_id = posts.author_id)
                or (f.addressee_id = auth.uid() and f.requester_id = posts.author_id))
        )
    );

create policy "Author can insert own posts" on posts
    for insert with check (author_id = auth.uid());

create policy "Author can delete own posts" on posts
    for delete using (author_id = auth.uid());

-- post_photos: inherits visibility from the parent post's own RLS.
create policy "Photos visible with their post" on post_photos
    for select using (
        exists (select 1 from posts p where p.id = post_photos.post_id)
    );

create policy "Author can insert own post photos" on post_photos
    for insert with check (
        exists (select 1 from posts p where p.id = post_photos.post_id and p.author_id = auth.uid())
    );

create policy "Author can delete own post photos" on post_photos
    for delete using (
        exists (select 1 from posts p where p.id = post_photos.post_id and p.author_id = auth.uid())
    );

-- post_likes: visible/likeable on any post you can already see.
create policy "Visible-post likes are visible" on post_likes
    for select using (
        exists (select 1 from posts p where p.id = post_likes.post_id)
    );

create policy "Users can like visible posts" on post_likes
    for insert with check (
        user_id = auth.uid()
        and exists (select 1 from posts p where p.id = post_likes.post_id)
    );

create policy "Users can remove their own like" on post_likes
    for delete using (user_id = auth.uid());

-- post_comments: same visibility rule as likes.
create policy "Visible-post comments are visible" on post_comments
    for select using (
        exists (select 1 from posts p where p.id = post_comments.post_id)
    );

create policy "Users can comment on visible posts" on post_comments
    for insert with check (
        author_id = auth.uid()
        and exists (select 1 from posts p where p.id = post_comments.post_id)
    );

create policy "Users can delete their own comments" on post_comments
    for delete using (author_id = auth.uid());

-- Storage bucket for post photos — public read, uploads/deletes scoped to
-- the uploader's own folder (same shape as the existing "avatars" bucket).
insert into storage.buckets (id, name, public)
values ('post-photos', 'post-photos', true)
on conflict (id) do nothing;

create policy "Public read post photos" on storage.objects
    for select using (bucket_id = 'post-photos');

create policy "Users can upload their own post photos" on storage.objects
    for insert with check (
        bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "Users can delete their own post photos" on storage.objects
    for delete using (
        bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text
    );
