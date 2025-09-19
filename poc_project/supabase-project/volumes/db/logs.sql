-- logs.sql
-- Analytics/Logflare가 수집하는 로그/지표를 저장할 테이블.
-- Studio/대시보드에서 확인 가능.

create table if not exists _analytics.logs (
    id         bigserial primary key,              -- 로그 PK
    log_level  text not null,                      -- 'debug' | 'info' | 'warn' | 'error'
    message    text not null,                      -- 메시지 본문
    meta       jsonb,                              -- 추가 맥락(요청ID, userId, 에러스택 등)
    created_at timestamptz default now()
);

-- 조회 최적화(대표 쿼리 패턴 기준): 수준/시간순 필터링
create index if not exists idx_logs_level_created_at
    on _analytics.logs(log_level, created_at);

create table if not exists _analytics.metrics (
    id         bigserial primary key,              -- 메트릭 PK
    name       text not null,                      -- 메트릭명(예: 'call_success_rate')
    value      numeric not null,                   -- 수치값
    tags       jsonb,                              -- 태그(예: {"region":"seoul","plan":"pro"})
    created_at timestamptz default now()
);

create index if not exists idx_metrics_name_created_at
    on _analytics.metrics(name, created_at);