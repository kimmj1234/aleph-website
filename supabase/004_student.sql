-- ALEPH 서버 4단계: 학생 대시보드
-- 003_teacher.sql 을 실행한 뒤, SQL Editor 에서 이 파일을 한 번 실행합니다.
--
-- 만드는 것
--   assignments : 과제 13개 (핵심 과제 T01~T11 + 마지막 A·B). 로그인한 누구나 읽기
--   submissions : 과제 제출. 학생은 본인 것만 내고 봄. 앞 과제가 모두 최종 승인돼야 다음 과제를 낼 수 있음
--                 상태: 제출됨 → 강사 확인 → 최종 승인(관리자) / 다시 제출 요청. 상태는 강사·관리자만 바꿈
--   rituals     : 아침·마무리 리추얼. 학생이 하루에 하나씩 쓰고 그날 안에만 고침. 강사·관리자는 읽기
-- 날짜는 한국 시간 기준 (서버 시계는 UTC 라서 아침 9시 전이 전날로 잡히지 않게)

-- ───────────── 과제 ─────────────
create table public.assignments (
  no          smallint primary key check (no between 1 and 99),   -- 진행 순서
  label       text not null unique,                                -- T01 … 마지막 A
  title       text not null,
  description text not null default ''
);
revoke all on public.assignments from anon, authenticated;
alter table public.assignments enable row level security;
grant select on public.assignments to authenticated;
grant select, insert, update, delete on public.assignments to service_role;
create policy "assignments: 로그인한 사람은 누구나 읽기" on public.assignments
  for select to authenticated
  using (true);

-- 과제 내용은 임시. 실제 과제가 정해지면 SQL Editor 에서 update 로 고칩니다
insert into public.assignments (no, label, title, description) values
  (1,  'T01', 'AI 도구와 첫 대화',        '외부 LLM 하나를 골라 가입하고, 자기소개를 부탁해 결과를 정리합니다.'),
  (2,  'T02', '좋은 질문 만들기',          '같은 질문을 세 가지로 바꿔 물어보고 답이 어떻게 달라지는지 비교합니다.'),
  (3,  'T03', '나만의 학습 노트',          'AI와 함께 이번 주 배운 내용을 한 장짜리 노트로 정리합니다.'),
  (4,  'T04', '첫 웹페이지',               'AI의 도움을 받아 자기소개 웹페이지를 만들고 인터넷에 올립니다.'),
  (5,  'T05', '데이터 읽기',               '공개 데이터 하나를 골라 AI로 요약하고 표와 그래프로 보여 줍니다.'),
  (6,  'T06', '자동화 한 가지',            '매일 반복하는 일 하나를 AI로 줄이는 방법을 만들어 봅니다.'),
  (7,  'T07', '오류 고치기',               '일부러 망가뜨린 코드를 AI와 함께 고치고 과정을 기록합니다.'),
  (8,  'T08', '작은 서비스 기획',          '주변의 불편 하나를 골라 해결하는 서비스를 한 장으로 기획합니다.'),
  (9,  'T09', '서비스 만들기',             'T08에서 기획한 서비스를 AI의 도움으로 직접 만듭니다.'),
  (10, 'T10', '피드백 반영',               '친구 두 명에게 써 보게 하고 받은 의견을 반영합니다.'),
  (11, 'T11', '발표 자료',                 '만든 서비스를 5분 안에 소개하는 발표 자료를 만듭니다.'),
  (12, '마지막 A', '포트폴리오 정리',      '지금까지의 결과물을 하나의 포트폴리오 페이지로 묶습니다.'),
  (13, '마지막 B', '최종 발표',            '포트폴리오를 바탕으로 최종 발표를 하고 영상이나 자료를 제출합니다.');

-- ───────────── 과제 제출 ─────────────
create table public.submissions (
  id            bigint generated always as identity primary key,
  student_id    uuid not null default auth.uid() references public.profiles on delete cascade,
  assignment_no smallint not null references public.assignments,
  result_url    text check (result_url ~ '^https?://' and char_length(result_url) <= 500),   -- 결과물 주소
  source_url    text check (source_url ~ '^https?://' and char_length(source_url) <= 500),   -- 소스 주소
  memo          text check (char_length(memo) <= 1000),
  status        text not null default 'submitted' check (status in ('submitted', 'checked', 'approved', 'returned')),
  created_at    timestamptz not null default now(),
  check (result_url is not null or source_url is not null)
);
create index submissions_student_idx on public.submissions (student_id, assignment_no);
create index submissions_assignment_idx on public.submissions (assignment_no);

-- 지금 학생이 할 차례인 과제 번호: 아직 최종 승인 안 된 과제 중 가장 앞 (다 끝났으면 null)
create function private.current_assignment()
returns smallint
language sql
stable
set search_path = ''
as $$
  select min(a.no) from public.assignments a
  where not exists (
    select 1 from public.submissions s
    where s.student_id = (select auth.uid()) and s.assignment_no = a.no and s.status = 'approved'
  );
$$;
revoke execute on function private.current_assignment() from public, anon;
grant execute on function private.current_assignment() to authenticated;

revoke all on public.submissions from anon, authenticated;
alter table public.submissions enable row level security;
grant select on public.submissions to authenticated;
grant insert (assignment_no, result_url, source_url, memo) on public.submissions to authenticated;   -- 상태·학생·시각은 서버가 정함
grant update (status) on public.submissions to authenticated;
grant select, insert, update, delete on public.submissions to service_role;

create policy "submissions: 본인·강사·관리자 읽기" on public.submissions
  for select to authenticated
  using (student_id = (select auth.uid()) or (select private.is_teacher()) or (select private.is_admin()));
create policy "submissions: 학생이 지금 차례 과제만 내기" on public.submissions
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'student')
    and assignment_no = (select private.current_assignment())
  );
create policy "submissions: 강사는 확인 또는 다시 제출 요청" on public.submissions
  for update to authenticated
  using ((select private.is_teacher()) and status <> 'approved')
  with check ((select private.is_teacher()) and status in ('checked', 'returned'));
create policy "submissions: 관리자는 모든 상태로" on public.submissions
  for update to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- ───────────── 리추얼 ─────────────
create table public.rituals (
  student_id  uuid not null default auth.uid() references public.profiles on delete cascade,
  day         date not null default (now() at time zone 'Asia/Seoul')::date,
  kind        text not null check (kind in ('open', 'close')),   -- open: 아침 · close: 마무리
  strength    text check (char_length(strength) <= 300),         -- 아침: 오늘 쓸 강점
  action      text check (char_length(action) <= 300),           -- 아침: 오늘의 행동
  result      text check (char_length(result) <= 500),           -- 마무리: 실행 결과
  next_action text check (char_length(next_action) <= 300),      -- 마무리: 다음 행동
  updated_at  timestamptz not null default now(),
  primary key (student_id, day, kind),
  check (case kind when 'open'  then strength is not null and action is not null
                   when 'close' then result is not null and next_action is not null end)
);

revoke all on public.rituals from anon, authenticated;
alter table public.rituals enable row level security;
grant select on public.rituals to authenticated;
grant insert (kind, strength, action, result, next_action),
      update (strength, action, result, next_action, updated_at) on public.rituals to authenticated;   -- 날짜는 서버가 정함
grant select, insert, update, delete on public.rituals to service_role;

create policy "rituals: 본인·강사·관리자 읽기" on public.rituals
  for select to authenticated
  using (student_id = (select auth.uid()) or (select private.is_teacher()) or (select private.is_admin()));
create policy "rituals: 학생이 본인 것 쓰기" on public.rituals
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'student')
  );
create policy "rituals: 오늘 것만 본인이 고치기" on public.rituals
  for update to authenticated
  using (student_id = (select auth.uid()) and day = (now() at time zone 'Asia/Seoul')::date)
  with check (student_id = (select auth.uid()) and day = (now() at time zone 'Asia/Seoul')::date);
