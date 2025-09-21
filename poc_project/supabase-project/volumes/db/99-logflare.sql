-- Logflare 기본 테이블 부트스트랩
-- 목적: Logflare 컨테이너가 시작될 때 참조하는 필수 테이블(users, sources, backends, system_metrics)을 미리 생성

-- users 테이블
create table if not exists public.users (
    id uuid primary key default gen_random_uuid(),
    email text,
    provider text,
    token text,
    api_key text,
    old_api_key text,
    email_preferred boolean,
    name text,
    image text,
    email_me_product boolean,
    admin boolean default false,
    phone text,
    bigquery_project_id text,
    bigquery_dataset_location text,
    bigquery_dataset_id text,
    bigquery_udfs_hash text,
    bigquery_processed_bytes_limit bigint,
    api_quota integer,
    valid_google_account boolean,
    provider_uid text,
    company text,
    billing_enabled boolean,
    endpoints_beta boolean,
    metadata jsonb default '{}'::jsonb,
    preferences jsonb default '{}'::jsonb,
    partner_upgraded boolean,
    partner_id uuid,
    inserted_at timestamptz default now(),
    updated_at timestamptz default now()
    );

-- sources 테이블
create table if not exists public.sources (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    service_name text,
    token text,
    public_token text,
    favorite boolean default false,
    bigquery_table_ttl integer,
    api_quota integer,
    webhook_notification_url text,
    slack_hook_url text,
    bq_table_partition_type text,
    custom_event_message_keys text[],
    log_events_updated_at timestamptz default now(),
    notifications_every integer,
    lock_schema boolean,
    validate_schema boolean,
    drop_lql_filters boolean,
    drop_lql_string boolean,
    v2_pipeline boolean,
    disable_tailing boolean,
    suggested_keys text[],
    transform_copy_fields jsonb default '{}'::jsonb,
    user_id uuid references public.users(id) on delete cascade,
    notifications jsonb default '{}'::jsonb,
    inserted_at timestamptz default now(),
    updated_at timestamptz default now()
    );

-- backends 테이블
create table if not exists public.backends (
    id uuid primary key default gen_random_uuid(),
    name text,
    description text,
    token text,
    type text,
    config_encrypted jsonb default '{}'::jsonb,
    user_id uuid references public.users(id) on delete cascade,
    metadata jsonb default '{}'::jsonb,
    inserted_at timestamptz default now(),
    updated_at timestamptz default now()
    );

-- system_metrics 테이블
create table if not exists public.system_metrics (
    id uuid primary key default gen_random_uuid(),
    node text,
    all_logs_logged boolean,
    inserted_at timestamptz default now(),
    updated_at timestamptz default now()
    );

-- sources_backends (sources와 backends 관계 테이블, 쿼리 로그에 등장)
create table if not exists public.sources_backends (
    source_id uuid references public.sources(id) on delete cascade,
    backend_id uuid references public.backends(id) on delete cascade,
    inserted_at timestamptz default now(),
    updated_at timestamptz default now(),
    primary key (source_id, backend_id)
    );