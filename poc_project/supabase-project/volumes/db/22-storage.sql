-- storage bucket 생성 (avatars)
insert into storage.buckets (id, name)
    values ('avatars', 'avatars')
    on conflict (id) do nothing;

-- 정책: avatars 버킷만 접근 허용
create policy "Avatar images are publicly accessible."
    on storage.objects for select
    using ( bucket_id = 'avatars' );

create policy "Anyone can upload an avatar."
    on storage.objects for insert
    with check ( bucket_id = 'avatars' );

create policy "Anyone can update an avatar."
    on storage.objects for update
    with check ( bucket_id = 'avatars' );