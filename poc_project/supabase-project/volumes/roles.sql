-- 익명 사용자 롤
create role anon nologin;

-- PostgREST 연결용 롤 (비번 아무거나)
create role authenticator login password 'authpass';

-- anon 권한 부여
grant usage on schema public to anon;
grant all on all tables in schema public to anon;
grant all on all sequences in schema public to anon;