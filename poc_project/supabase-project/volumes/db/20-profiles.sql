-- 20-profiles.sql
-- 목적: 튜토리얼/데모에서 자주 쓰는 profiles 테이블과 RLS 정책을 분리 제공
-- 주의: auth.users 테이블이 없는 환경(로컬 PoC)에서도 "적어도 에러 없이" 로드되도록
--       FK는 조건부로 추가하고, RLS 정책은 표준 Supabase 예제와 동일하게 둔다.

create schema if not exists auth;

--  - JWT 클레임(request.jwt.claims)에서 'sub'를 꺼내 uuid로 반환 (없으면 NULL)
do $$
begin
    if not exists (
        select 1
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'auth' and p.proname = 'uid'
    ) then
        create or replace function auth.uid()
        returns uuid
        language sql
        stable
        as $fn$
            select (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid;
        $fn$;
    end if;
end
$$;

-- profiles 테이블 생성
--  - id: 사용자 식별자 (원칙적으로 auth.users.id와 동일한 uuid)
--  - updated_at / username / avatar_url / website: 샘플 필드
--  - username 길이 제한 체크
create table if not exists public.profiles (
    id uuid not null,
    updated_at timestamptz,
    username text unique,
    avatar_url text,
    website text,
    constraint profiles_pkey primary key (id),
    constraint username_length check (char_length(username) >= 3)
);

-- (선택/조건부) auth.users가 존재하는 경우에만 FK를 추가
--  - 로컬 PoC에서 auth.users가 없을 수 있음 -> 이 경우 FK 미부여
do $$
declare
    has_auth_users boolean;
    has_fk boolean;
begin
    select exists (
        select 1
        from information_schema.tables
        where table_schema = 'auth' and table_name = 'users'
    ) into has_auth_users;

    select exists (
        select 1
        from information_schema.table_constraints
        where table_schema = 'public'
            and table_name = 'profiles'
            and constraint_type = 'FOREIGN KEY'
    ) into has_fk;

    if has_auth_users and not has_fk then
        execute $x$
            alter table public.profiles
                add constraint profiles_id_fkey
                foreign key (id) references auth.users(id) on delete cascade
        $x$;
    end if;
end
$$;

-- RLS 활성화
alter table public.profiles enable row level security;

-- (정책) 본인만 select 가능
do $$
begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'profiles' and policyname = 'Public profiles are viewable by the owner.'
    ) then
        create policy "Public profiles are viewable by the owner."
            on public.profiles for select
            using (auth.uid() = id);
    end if;
end
$$;

-- (정책) 본인만 insert 가능
do $$
begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'profiles' and policyname = 'Users can insert their own profile.'
    ) then
        create policy "Users can insert their own profile."
            on public.profiles for insert
            with check (auth.uid() = id);
    end if;
end
$$;

-- (정책) 본인만 update 가능
do $$
begin
    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'profiles' and policyname = 'Users can update own profile.'
    ) then
        create policy "Users can update own profile."
            on public.profiles for update
            using (auth.uid() = id);
    end if;
end
$$;

-- Realtime publication에 profiles 등록(중복 방지)
do $$
begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime') and
        not exists (
            select 1 from pg_publication_tables
            where pubname = 'supabase_realtime'
                and schemaname = 'public'
                and tablename = 'profiles'
        )
    then
        execute 'alter publication supabase_realtime add table public.profiles';
    end if;
end
$$;