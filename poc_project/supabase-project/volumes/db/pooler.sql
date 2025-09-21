-- pooler.sql
-- pgbouncer(커넥션 풀러)가 DB에 접속할 계정과 최소 권한을 설정.

do $$ begin
  if not exists (select from pg_roles where rolname = 'pgbouncer') then
create role pgbouncer login password 'devlocal-pgbouncer'; -- 비번
end if;
end $$;

-- 풀러가 접근만 할 수 있도록 최소 권한(USAGE) 부여. 실제 테이블 접근은 애플리케이션 롤이 수행.
grant usage on schema public     to pgbouncer;
grant usage on schema _supabase  to pgbouncer;