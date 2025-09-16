create table profiles (
  id uuid references auth.users not null,
  updated_at timestamp with time zone,
  username text unique,
  avatar_url text,
  website text,

  primary key (id),
  unique(username),
  constraint username_length check (char_length(username) >= 3)
);

alter table profiles enable row level security;

create policy "Public profiles are viewable by the owner."
  on profiles for select
  using ( auth.uid() = id );

create policy "Users can insert their own profile."
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );

-- Set up Realtime
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
alter publication supabase_realtime add table profiles;

-- WebRTC 시그널링 테이블
create table webrtc_signaling (
  id uuid default gen_random_uuid() primary key,
  room_id text not null,
  user_id text not null,
  message_type text not null, -- 'offer', 'answer', 'ice-candidate'
  message_data jsonb not null,
  created_at timestamp with time zone default now()
);

-- 방 관리 테이블
create table webrtc_rooms (
  id text primary key,
  created_by text not null,
  created_at timestamp with time zone default now(),
  is_active boolean default true
);

-- WebRTC 테이블에 RLS 활성화
alter table webrtc_signaling enable row level security;
alter table webrtc_rooms enable row level security;

-- WebRTC 시그널링 정책
create policy "Anyone can insert signaling messages"
  on webrtc_signaling for insert
  with check (true);

create policy "Anyone can select signaling messages"
  on webrtc_signaling for select
  using (true);

create policy "Anyone can insert rooms"
  on webrtc_rooms for insert
  with check (true);

create policy "Anyone can select rooms"
  on webrtc_rooms for select
  using (true);

-- Realtime에 WebRTC 테이블 추가
alter publication supabase_realtime add table webrtc_signaling;
alter publication supabase_realtime add table webrtc_rooms;

-- Set up Storage
insert into storage.buckets (id, name)
values ('avatars', 'avatars');

create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Anyone can upload an avatar."
  on storage.objects for insert
  with check ( bucket_id = 'avatars' );

create policy "Anyone can update an avatar."
  on storage.objects for update
  with check ( bucket_id = 'avatars' );
