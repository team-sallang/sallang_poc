-- roles.sql
-- 비밀번호는 예시값
-- PoC 외 환경에선 반드시 강한 비밀번호로 교체하거나, 별도 .sh에서 ${POSTGRES_PASSWORD}를 주입해야됨

-- 관리자 (DB 슈퍼유저; Studio/운영 작업용) — 실제 운영에선 별도의 관리 흐름 권장
do $$ begin
  if not exists (select from pg_roles where rolname = 'supabase_admin') then
create role supabase_admin superuser login password 'devlocal-admin';
end if;
end $$;

-- API 진입점 (Kong/PostgREST가 붙는 계정). 여기서 다른 롤을 대행(impersonate)한다.
do $$ begin
  if not exists (select from pg_roles where rolname = 'authenticator') then
create role authenticator noinherit login password 'devlocal-authenticator';
end if;
end $$;

-- 비로그인 사용자 롤(익명)
do $$ begin
  if not exists (select from pg_roles where rolname = 'anon') then
create role anon noinherit login password 'devlocal-anon';
end if;
end $$;

-- 로그인 사용자 롤
do $$ begin
  if not exists (select from pg_roles where rolname = 'authenticated') then
create role authenticated noinherit login password 'devlocal-authenticated';
end if;
end $$;

-- 내부 서비스용(백오피스/배치). 권한이 강하므로 노출 금지.
do $$ begin
  if not exists (select from pg_roles where rolname = 'service_role') then
create role service_role noinherit login password 'devlocal-service';
end if;
end $$;

-- 스키마 접근(최소한의 USAGE만). 실제 테이블 권한은 각 스크립트에서 별도 GRANT 또는 RLS로 제어 권장.
grant usage on schema public     to anon, authenticated;
grant usage on schema _realtime  to anon, authenticated;
grant usage on schema _analytics to service_role;

-- authenticator가 세 롤을 대행할 수 있게 한다. (JWT의 role 클레임에 따라 SET ROLE)
grant anon           to authenticator;
grant authenticated  to authenticator;
grant service_role   to authenticator;