-- jwt.sql
-- DB에서 JWT 클레임을 읽고 쓰기 편하도록 헬퍼 함수를 제공
-- PostgREST/Realtime는 요청마다 'request.jwt.claims' GUC에 JWT payload를 넣어준다.

-- 현재 세션의 JWT 클레임(JSONB) 반환. RLS 또는 트리거에서 사용자 맥락 파악 시 사용.
create or replace function auth.jwt()
returns jsonb
language sql stable
as $$
select current_setting('request.jwt.claims', true)::jsonb; -- 존재하지 않으면 NULL
$$;

-- JWT에서 사용자 식별자 추출: sub 또는 user_id 중 하나를 UUID로 해석
create or replace function auth.uid()
returns uuid
language sql stable
as $$
select coalesce(
    nullif((auth.jwt() ->> 'sub')::text, ''),       -- 표준 sub
    nullif((auth.jwt() ->> 'user_id')::text, '')    -- 일부 토큰은 user_id 사용
)::uuid;
$$;