-- ALEPH 서버 5단계: 학생 대시보드 보강 (기존 포털 cortex 기준)
-- 004_student.sql 을 실행한 뒤, SQL Editor 에서 이 파일을 한 번 실행합니다.
--
-- 만드는 것
--   빠뜨린 리추얼: 지난 7일 안의 날짜로 리추얼을 늦게 쓸 수 있음 (늦게 쓴 기록은 created_at 으로 구분)
--   help_requests : 학생 도움 요청과 강사·관리자 답변

-- ───────────── 빠뜨린 리추얼 ─────────────
alter table public.rituals add column created_at timestamptz not null default now();   -- 처음 쓴 시각 (날짜보다 늦으면 '늦은 작성')
grant insert (day) on public.rituals to authenticated;
drop policy "rituals: 학생이 본인 것 쓰기" on public.rituals;
create policy "rituals: 학생이 본인 것 쓰기 (오늘 또는 지난 7일)" on public.rituals
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'student')
    and day between (now() at time zone 'Asia/Seoul')::date - 7 and (now() at time zone 'Asia/Seoul')::date
  );

-- ───────────── 도움 요청 ─────────────
create table public.help_requests (
  id          bigint generated always as identity primary key,
  student_id  uuid not null default auth.uid() references public.profiles on delete cascade,
  question    text not null check (char_length(trim(question)) between 1 and 1000),
  answer      text check (char_length(answer) <= 2000),
  answered_by uuid references public.profiles on delete set null,
  answered_at timestamptz,
  created_at  timestamptz not null default now()
);
create index help_requests_student_idx on public.help_requests (student_id);
create index help_requests_answered_by_idx on public.help_requests (answered_by);

revoke all on public.help_requests from anon, authenticated;
alter table public.help_requests enable row level security;
grant select on public.help_requests to authenticated;
grant insert (question) on public.help_requests to authenticated;
grant update (answer, answered_by, answered_at) on public.help_requests to authenticated;
grant select, insert, update, delete on public.help_requests to service_role;

create policy "help_requests: 본인·강사·관리자 읽기" on public.help_requests
  for select to authenticated
  using (student_id = (select auth.uid()) or (select private.is_teacher()) or (select private.is_admin()));
create policy "help_requests: 학생이 묻기" on public.help_requests
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'student')
  );
create policy "help_requests: 강사·관리자가 답하기 (답한 사람은 본인)" on public.help_requests
  for update to authenticated
  using ((select private.is_teacher()) or (select private.is_admin()))
  with check (((select private.is_teacher()) or (select private.is_admin())) and answered_by = (select auth.uid()));
