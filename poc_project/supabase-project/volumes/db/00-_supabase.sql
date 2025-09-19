-- 00-_supabase.sql
-- supabase의 내부 스키마와 확장 생성
-- 의존성 - roles/jwt/realtime/logs 스크립트
-- Studio/Realtime/Analytics가 이 스크립트 사용

-- 내부 관리/메타 스키마들 (존재하지 않으면 생성)
create schema if not exists _supabase;   -- Studio/웹훅 등 내부 메타 테이블 보관
create schema if not exists _analytics;  -- 로그/메트릭 적재
create schema if not exists _realtime;   -- Realtime 내부 테이블/뷰(이미지에 따라 사용)
create schema if not exists auth;        -- JWT/보조 함수 등 auth 관련 네임스페이스

-- 확장 설치
create extension if not exists pgcrypto; -- 랜덤/해시 등 암호 유틸
create extension if not exists pgsodium; -- KMS/키관리; supabase/postgres는 /etc/postgresql-custom 에 키 보존
create extension if not exists pgjwt;    -- JWT 생성/검증 함수 모음
create extension if not exists "uuid-ossp"; -- UUID v4 등 생성

-- 최소 이벤트 테이블(선택): Analytics UI/Studio에서 간단히 조회 테스트할 때 유용
create table if not exists _analytics.events (
    id bigserial primary key,                 -- PK
    event_type text not null,                 -- 이벤트 유형(예: 'call_started')
    payload jsonb not null,                   -- 원문 페이로드
    created_at timestamptz default now()      -- 생성 시간
);