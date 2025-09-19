-- WebRTC 방 관리
create table if not exists public.webrtc_rooms (
    id text primary key,
    created_by text not null,
    created_at timestamptz default now(),
    is_active boolean default true
);

-- WebRTC signaling 메시지
create table if not exists public.webrtc_signaling (
    id uuid default gen_random_uuid() primary key,
    room_id text not null references public.webrtc_rooms(id) on delete cascade,
    user_id text not null,
    message_type text not null,
    message_data jsonb not null,
    created_at timestamptz default now()
);

-- RLS 활성화
alter table public.webrtc_rooms enable row level security;
alter table public.webrtc_signaling enable row level security;

-- PoC 정책 (모두 허용)
create policy "Anyone can insert rooms"
  on public.webrtc_rooms for insert
  with check (true);

create policy "Anyone can select rooms"
  on public.webrtc_rooms for select
  using (true);

create policy "Anyone can insert signaling messages"
  on public.webrtc_signaling for insert
  with check (true);

create policy "Anyone can select signaling messages"
  on public.webrtc_signaling for select
                                                   using (true);

-- Realtime publication에 추가
alter publication supabase_realtime add table public.webrtc_rooms;
alter publication supabase_realtime add table public.webrtc_signaling;