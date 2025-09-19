-- jwt.sql
-- 최소버전으로 작성
-- 이러면 보안, 인증 로직 다 빼고 컨테이너만 올라가도록 설정(DB를 모드 anon권한으로 ㅇ열어둠)
create schema if not exists auth;

-- PostgREST가 JWT payload를 읽을 때 참조하는 함수
create or replace function auth.jwt()
returns jsonb
language sql stable
as $$
select current_setting('request.jwt.claims', true)::jsonb;
$$;