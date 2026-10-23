-- ALEPH 서버(Supabase) 초기 설정
-- Supabase 대시보드 > SQL Editor 에 이 파일 내용을 통째로 붙여넣고 Run 하면 됩니다. (한 번만)
--
-- 만드는 것
--   profiles       : 회원 정보 (학생 / 강사 / 관리자 역할)
--   teacher_codes  : 관리자가 발급하는 강사 고유 코드 (한 코드는 강사 한 명만 사용)
--   가입 트리거    : 회원가입 때 프로필을 만들고, 강사면 고유 코드를 확인해 사용 처리
--   verify_teacher_code : 강사 로그인 때 그 강사가 가입에 쓴 코드가 맞는지 확인
--
-- 권한 원칙
--   - 역할(role)은 profiles 에만 저장하고, 사용자가 고칠 수 있는 user_metadata 로는 권한을 판단하지 않음
--   - 브라우저(authenticated)는 꼭 필요한 것만: 자기 프로필 읽기, 관리자만 코드 읽기·발급·삭제
--   - 관리자 지정은 사이트가 아니라 이 SQL Editor 에서만 (맨 아래 참고)

create schema if not exists private;

-- ───────────── 회원 정보 ─────────────
create table public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  userid     text not null unique,                       -- 로그인 아이디 (영문·숫자 4~16자)
  name       text not null,
  role       text not null default 'student' check (role in ('student', 'teacher', 'admin')),
  extra      jsonb not null default '{}'::jsonb,         -- 회원가입 2단계 답변
  created_at timestamptz not null default now()
);

-- ───────────── 강사 고유 코드 ─────────────
create table public.teacher_codes (
  code       text primary key default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
  created_by uuid references public.profiles on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  used_by    uuid unique references public.profiles on delete set null,   -- 이 코드로 가입한 강사
  used_at    timestamptz
);
create index teacher_codes_created_by_idx on public.teacher_codes (created_by);

-- ───────────── 관리자 확인 (RLS 정책에서 사용) ─────────────
create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;
revoke execute on function private.is_admin() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;

-- ───────────── 접근 권한 + RLS ─────────────
revoke all on public.profiles, public.teacher_codes from anon, authenticated;

alter table public.profiles enable row level security;
alter table public.teacher_codes enable row level security;

grant select on public.profiles to authenticated;
create policy "profiles: 본인 또는 관리자만 읽기" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id or (select private.is_admin()));

grant select, insert, delete on public.teacher_codes to authenticated;
create policy "teacher_codes: 관리자만 읽기" on public.teacher_codes
  for select to authenticated
  using ((select private.is_admin()));
create policy "teacher_codes: 관리자만 발급" on public.teacher_codes
  for insert to authenticated
  with check ((select private.is_admin()) and used_by is null);
create policy "teacher_codes: 관리자만 아직 안 쓴 코드 삭제" on public.teacher_codes
  for delete to authenticated
  using ((select private.is_admin()) and used_by is null);

grant select, insert, update, delete on public.profiles, public.teacher_codes to service_role;

-- ───────────── 회원가입 트리거 ─────────────
-- 가입 때 보낸 정보(options.data): userid, name, role('student'|'teacher'), teacher_code, extra
-- 강사인데 코드가 없거나 틀리거나 이미 쓰인 코드면 예외를 내서 가입 자체를 막음
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  r    text  := coalesce(meta ->> 'role', 'student');
begin
  if r not in ('student', 'teacher') then
    raise exception 'INVALID_ROLE';            -- 관리자는 가입으로 만들 수 없음
  end if;

  insert into public.profiles (id, userid, name, role, extra)
  values (new.id, meta ->> 'userid', meta ->> 'name', r, coalesce(meta -> 'extra', '{}'::jsonb));

  if r = 'teacher' then
    update public.teacher_codes
       set used_by = new.id, used_at = now()
     where code = upper(trim(meta ->> 'teacher_code'))
       and used_by is null;
    if not found then
      raise exception 'TEACHER_CODE_INVALID';
    end if;
  end if;

  return new;
end;
$$;
revoke execute on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure private.handle_new_user();

-- ───────────── 강사 로그인 확인 ─────────────
-- 로그인한 강사 본인이 가입에 쓴 코드와 입력한 코드가 같은지만 알려줌 (다른 코드 정보는 노출 안 함)
create function public.verify_teacher_code(input text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.teacher_codes
    where used_by = (select auth.uid())
      and code = upper(trim(input))
  );
$$;
revoke execute on function public.verify_teacher_code(text) from public, anon;
grant execute on function public.verify_teacher_code(text) to authenticated;

-- ───────────── 관리자 지정 (가입 후 SQL Editor 에서 한 번) ─────────────
-- 1) 사이트에서 '학생 회원가입'으로 관리자용 아이디를 만든 뒤
-- 2) 아래 줄의 'admin' 을 그 아이디로 바꿔 실행
-- update public.profiles set role = 'admin' where userid = 'admin';
