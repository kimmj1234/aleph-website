-- ALEPH 서버 3단계: 강사 화면
-- 002_dashboard.sql 을 실행한 뒤, SQL Editor 에서 이 파일을 한 번 실행합니다.
--
-- 만드는 것
--   profiles.bio, profiles.subjects : 강사 프로필 (한 줄 소개, 담당 분야)
--   강사·관리자가 본인 프로필(이름·소개·담당 분야)을 고치는 권한
--   강사가 학생 회원 정보를 읽는 권한 (학생 관리)
--   student_notes : 강사가 학생마다 남기는 메모 (쓴 강사 본인과 관리자만 볼 수 있음)

-- ───────────── 강사 프로필 ─────────────
alter table public.profiles
  add column bio      text check (char_length(bio) <= 200),        -- 한 줄 소개
  add column subjects text[] not null default '{}';                 -- 담당 분야

create function private.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'teacher'
  );
$$;
revoke execute on function private.is_teacher() from public, anon;
grant execute on function private.is_teacher() to authenticated;

-- 이름은 002 에서 이미 허용. 소개·담당 분야도 고칠 수 있게 (어느 줄인지는 아래 정책이 정함)
grant update (bio, subjects) on public.profiles to authenticated;
create policy "profiles: 강사·관리자는 본인 프로필 고치기" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id and role in ('teacher', 'admin'))
  with check ((select auth.uid()) = id and role in ('teacher', 'admin'));

-- 학생 관리: 강사는 학생 회원 정보를 읽을 수 있음 (다른 강사·관리자 정보는 못 봄)
create policy "profiles: 강사는 학생 정보 읽기" on public.profiles
  for select to authenticated
  using (role = 'student' and (select private.is_teacher()));

-- ───────────── 학생 메모 ─────────────
create table public.student_notes (
  student_id uuid not null references public.profiles on delete cascade,
  teacher_id uuid not null default auth.uid() references public.profiles on delete cascade,
  note       text not null check (char_length(note) between 1 and 1000),
  updated_at timestamptz not null default now(),
  primary key (student_id, teacher_id)
);
create index student_notes_teacher_id_idx on public.student_notes (teacher_id);

revoke all on public.student_notes from anon, authenticated;
alter table public.student_notes enable row level security;
grant select, delete on public.student_notes to authenticated;
grant insert (student_id, note), update (note, updated_at) on public.student_notes to authenticated;
grant select, insert, update, delete on public.student_notes to service_role;

create policy "student_notes: 쓴 강사 본인과 관리자만 읽기" on public.student_notes
  for select to authenticated
  using (teacher_id = (select auth.uid()) or (select private.is_admin()));
create policy "student_notes: 강사가 학생에게만 쓰기" on public.student_notes
  for insert to authenticated
  with check (
    teacher_id = (select auth.uid()) and (select private.is_teacher())
    and exists (select 1 from public.profiles p where p.id = student_id and p.role = 'student')
  );
create policy "student_notes: 쓴 강사 본인만 고치기" on public.student_notes
  for update to authenticated
  using (teacher_id = (select auth.uid()))
  with check (teacher_id = (select auth.uid()));
create policy "student_notes: 쓴 강사 본인만 지우기" on public.student_notes
  for delete to authenticated
  using (teacher_id = (select auth.uid()));
