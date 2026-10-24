-- ALEPH 서버 7단계: 리추얼 페이지를 강사·관리자도 사용
-- 006_classes.sql 을 실행한 뒤, SQL Editor 에서 이 파일을 한 번 실행합니다.
--
-- 바꾸는 것
--   rituals 쓰기를 학생만 → 로그인한 누구나 '본인 것'으로.
--   강사·관리자가 쓴 기록은 체험(시뮬레이션) 기록: 본인 계정에만 남고, 학생 화면의 성장 통계는 학생 본인 기록만 셈

drop policy "rituals: 학생이 본인 것 쓰기 (오늘 또는 지난 7일)" on public.rituals;
create policy "rituals: 본인 것 쓰기 (오늘 또는 지난 7일)" on public.rituals
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and day between (now() at time zone 'Asia/Seoul')::date - 7 and (now() at time zone 'Asia/Seoul')::date
  );
