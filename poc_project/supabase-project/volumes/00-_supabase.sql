-- 내부 관리용 스키마
create schema if not exists _supabase;
create schema if not exists _analytics;
create schema if not exists _realtime;
create schema if not exists auth;

-- 확장 설치 (이미지에 내장돼 있을 가능성 높음)
create extension if not exists pgcrypto;
create extension if not exists pgsodium;
create extension if not exists pgjwt;
create extension if not exists uuid-ossp;

-- analytics용 기본 테이블
create table if not exists _analytics.events (
    id bigserial primary key,
    event_type text not null,
    payload jsonb not null,
    created_at timestamptz default now()
);