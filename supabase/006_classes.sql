-- ALEPH 서버 6단계: 반 (기존 포털의 반 요청·승인, 개강 전 안내, 반 공지)
-- 005_cortex.sql 을 실행한 뒤, SQL Editor 에서 이 파일을 한 번 실행합니다.
--
-- 만드는 것
--   classes       : 반 (이름·개강일·담당 강사). 로그인한 누구나 읽기, 관리자만 만들고 고치고 지움
--   class_members : 학생의 반 입장 요청 (학생 한 명당 한 반). 담당 강사·관리자가 승인/거절
--   class_notices : 반 공지. 그 반의 승인된 학생과 강사·관리자가 읽고, 담당 강사·관리자가 씀

-- ───────────── 반 ─────────────
create table public.classes (
  id         bigint generated always as identity primary key,
  name       text not null unique check (char_length(trim(name)) between 1 and 40),   -- 예) 대전 C반
  starts_on  date not null,                                                            -- 개강일
  teacher_id uuid references public.profiles on delete set null,                      -- 담당 강사
  created_at timestamptz not null default now()
);
create index classes_teacher_idx on public.classes (teacher_id);

-- 내가 이 반의 담당 강사인지
create function private.teaches(cid bigint)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.classes c where c.id = cid and c.teacher_id = (select auth.uid()));
$$;
revoke execute on function private.teaches(bigint) from public, anon;
grant execute on function private.teaches(bigint) to authenticated;

revoke all on public.classes from anon, authenticated;
alter table public.classes enable row level security;
grant select, delete on public.classes to authenticated;
grant insert (name, starts_on, teacher_id), update (name, starts_on, teacher_id) on public.classes to authenticated;
grant select, insert, update, delete on public.classes to service_role;

create policy "classes: 로그인한 사람은 누구나 읽기" on public.classes
  for select to authenticated
  using (true);
create policy "classes: 관리자만 만들기 (담당은 강사만)" on public.classes
  for insert to authenticated
  with check (
    (select private.is_admin())
    and (teacher_id is null or exists (select 1 from public.profiles p where p.id = teacher_id and p.role = 'teacher'))
  );
create policy "classes: 관리자만 고치기 (담당은 강사만)" on public.classes
  for update to authenticated
  using ((select private.is_admin()))
  with check (
    (select private.is_admin())
    and (teacher_id is null or exists (select 1 from public.profiles p where p.id = teacher_id and p.role = 'teacher'))
  );
create policy "classes: 관리자만 지우기" on public.classes
  for delete to authenticated
  using ((select private.is_admin()));

-- ───────────── 반 입장 요청 ─────────────
create table public.class_members (
  student_id   uuid primary key default auth.uid() references public.profiles on delete cascade,   -- 학생 한 명당 한 반
  class_id     bigint not null references public.classes on delete cascade,
  status       text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  decided_by   uuid references public.profiles on delete set null,
  decided_at   timestamptz
);
create index class_members_class_idx on public.class_members (class_id);
create index class_members_decided_by_idx on public.class_members (decided_by);

revoke all on public.class_members from anon, authenticated;
alter table public.class_members enable row level security;
grant select, delete on public.class_members to authenticated;
grant insert (class_id) on public.class_members to authenticated;                           -- 상태는 서버가 '대기'로 정함
grant update (status, decided_by, decided_at) on public.class_members to authenticated;
grant select, insert, update, delete on public.class_members to service_role;

create policy "class_members: 본인·강사·관리자 읽기" on public.class_members
  for select to authenticated
  using (student_id = (select auth.uid()) or (select private.is_teacher()) or (select private.is_admin()));
create policy "class_members: 학생이 입장 요청" on public.class_members
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'student')
  );
create policy "class_members: 담당 강사·관리자가 승인·거절 (결정한 사람은 본인)" on public.class_members
  for update to authenticated
  using ((select private.teaches(class_id)) or (select private.is_admin()))
  with check (
    ((select private.teaches(class_id)) or (select private.is_admin()))
    and decided_by = (select auth.uid()) and status in ('approved', 'rejected')
  );
create policy "class_members: 학생은 승인 전 요청 취소, 관리자는 모두" on public.class_members
  for delete to authenticated
  using ((student_id = (select auth.uid()) and status <> 'approved') or (select private.is_admin()));

-- ───────────── 반 공지 ─────────────
create table public.class_notices (
  id         bigint generated always as identity primary key,
  class_id   bigint not null references public.classes on delete cascade,
  body       text not null check (char_length(trim(body)) between 1 and 500),
  created_by uuid default auth.uid() references public.profiles on delete set null,
  created_at timestamptz not null default now()
);
create index class_notices_class_idx on public.class_notices (class_id);
create index class_notices_created_by_idx on public.class_notices (created_by);

revoke all on public.class_notices from anon, authenticated;
alter table public.class_notices enable row level security;
grant select, delete on public.class_notices to authenticated;
grant insert (class_id, body) on public.class_notices to authenticated;
grant select, insert, update, delete on public.class_notices to service_role;

create policy "class_notices: 그 반 승인 학생·강사·관리자 읽기" on public.class_notices
  for select to authenticated
  using (
    (select private.is_teacher()) or (select private.is_admin())
    or exists (select 1 from public.class_members m
               where m.student_id = (select auth.uid()) and m.class_id = class_notices.class_id and m.status = 'approved')
  );
create policy "class_notices: 담당 강사·관리자가 쓰기" on public.class_notices
  for insert to authenticated
  with check (created_by = (select auth.uid()) and ((select private.teaches(class_id)) or (select private.is_admin())));
create policy "class_notices: 쓴 사람·관리자가 지우기" on public.class_notices
  for delete to authenticated
  using (created_by = (select auth.uid()) or (select private.is_admin()));
