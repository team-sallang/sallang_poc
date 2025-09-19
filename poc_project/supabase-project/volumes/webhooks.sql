-- webhooks.sql

create table if not exists _supabase.webhooks (
    id         bigserial primary key,               -- 웹훅 식별자
    name       text not null,                       -- 표시명
    url        text not null,                       -- 호출 대상 URL
    secret     text,                                -- 서명 검증용 시크릿(옵션)
    is_active  boolean not null default true,       -- 비활성화 플래그
    created_at timestamptz default now()
);