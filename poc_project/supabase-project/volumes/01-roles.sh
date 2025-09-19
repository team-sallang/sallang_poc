#!/usr/bin/env bash
# 01-roles.sh
# SQL로 하드코딩한 예시 비밀번호 대신, 환경변수(${POSTGRES_PASSWORD} 등)를 주입해 안전하게 교체한다.
# docker-entrypoint-initdb.d는 .sh도 실행한다. 이 스크립트는 초기 1회 실행 시 psql로 비번을 교체.
# compose에서: - ./volumes/01-roles.sh:/docker-entrypoint-initdb.d/01-roles.sh:Z  (실행권한 +x 필수)

set -euo pipefail
export PGPASSWORD="${POSTGRES_PASSWORD:-postgres}"

psql -v ON_ERROR_STOP=1 --username "postgres" <<'SQL'
  alter role supabase_admin    with password '${POSTGRES_PASSWORD}';
  alter role authenticator     with password '${POSTGRES_PASSWORD}';
  alter role anon              with password '${POSTGRES_PASSWORD}';
  alter role authenticated     with password '${POSTGRES_PASSWORD}';
  alter role service_role      with password '${POSTGRES_PASSWORD}';
SQL

# [주의] 위 예시는 모든 롤에 동일 비번을 넣는다. 실제 운영에선 롤별 서로 다른 강력 비번 사용 권장.