-- 간소화버전 생성
-- 이러면 모든 요청이 anon권한으로 실행돼서 별도 인증없이도 insert/select로 가능해짐

-- 익명 사용자 롤
create role anon nologin;

-- PostgREST 연결용 롤 (비번 아무거나)
create role authenticator login password '${POSTGRES_PASSWORD}';

-- anon 권한 부여
grant usage on schema public to anon;
grant all on all tables in schema public to anon;
grant all on all sequences in schema public to anon;