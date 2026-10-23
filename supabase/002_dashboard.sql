-- ALEPH 서버 2단계: 관리자 대시보드
-- setup.sql 을 실행한 뒤, SQL Editor 에서 이 파일을 한 번 실행합니다.
--
-- 만드는 것
--   notices : 공지사항 (로그인한 누구나 읽기, 관리자만 쓰기·고치기·지우기)
--   관리자가 회원 이름을 고칠 수 있는 권한 (역할·아이디는 못 바꿈: 강사 로그인은 가입 코드가 있어야 해서)

-- ───────────── 공지사항 ─────────────
create table public.notices (
  id         bigint generated always as identity primary key,
  title      text not null check (length(trim(title)) between 1 and 100),
  pinned     boolean not null default false,                        -- 상단 고정
  created_by uuid references public.profiles on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);
create index notices_created_by_idx on public.notices (created_by);

revoke all on public.notices from anon, authenticated;
alter table public.notices enable row level security;

grant select on public.notices to authenticated;
grant insert (title, pinned), update (title, pinned), delete on public.notices to authenticated;
grant select, insert, update, delete on public.notices to service_role;

create policy "notices: 로그인한 사람은 누구나 읽기" on public.notices
  for select to authenticated
  using (true);
create policy "notices: 관리자만 쓰기" on public.notices
  for insert to authenticated
  with check ((select private.is_admin()));
create policy "notices: 관리자만 고치기" on public.notices
  for update to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));
create policy "notices: 관리자만 지우기" on public.notices
  for delete to authenticated
  using ((select private.is_admin()));

-- ───────────── 관리자: 회원 이름 고치기 ─────────────
-- 열 단위 권한으로 name 만 고칠 수 있음 (role·userid·extra 는 브라우저에서 못 바꿈)
grant update (name) on public.profiles to authenticated;
create policy "profiles: 관리자만 고치기" on public.profiles
  for update to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));
