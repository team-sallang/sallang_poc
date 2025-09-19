-- realtime.sql
-- WebRTC 시그널링 테이블을 정의한다.
-- 테이블 변경을 WebSocket으로 브로드캐스트한다.


-- 모든 테이블을 내보내는 publication (PoC에서는 간단하게 ALL; 운영에선 포함 테이블을 제한 권장)
do $$
begin
    if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        create publication supabase_realtime for all tables;   -- Realtime가 연결할 publication 이름
end if;
end
$$;

-- 1:1 방 메타: PoC에서는 text id로 매핑.
-- 운영에선 uuid PK/인덱스/가비지 수집 컬럼 확장해도 좋을듯
create table if not exists public.webrtc_rooms (
    id         text primary key,                   -- 클라이언트가 입력하는 방 ID
    created_by text not null,                      -- 생성자(앱 사용자 식별자; 지금은 text로 단순화)
    is_active  boolean not null default true,      -- 방 비활성화 플래그 (종료 처리 시 false)
    created_at timestamptz not null default now()  -- 생성 시각(정렬/청소에 사용)
);

-- 시그널링 메시지 저장: 'INSERT' 이벤트를 Realtime가 방송한다.
create table if not exists public.webrtc_signaling (
    id           bigserial primary key,            -- 메시지 PK
    room_id      text not null references public.webrtc_rooms(id) on delete cascade, -- 방 FK (방 삭제 시 메시지도 삭제)
    user_id      text not null,                    -- 송신자 식별자(지금은 text; 나중에 FK 교체 가능)
    message_type text not null,                    -- 'offer' | 'answer' | 'ice-candidate' 등
    message_data jsonb not null,                   -- SDP/ICE candidate 원문(JSON)
    created_at   timestamptz not null default now()
);

-- 조회 성능 인덱스: 방별 최신순 스트림 처리에 유용
create index if not exists idx_webrtc_signaling_room_created_at
    on public.webrtc_signaling(room_id, created_at);

create index if not exists idx_webrtc_signaling_type
    on public.webrtc_signaling(message_type);

-- 접근 권한 (PoC에선 넉넉히 부여; 운영 전환 시 RLS로 강화 권장)
grant select, insert, update, delete on public.webrtc_rooms     to anon, authenticated;
grant select, insert, update, delete on public.webrtc_signaling to anon, authenticated;