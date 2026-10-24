\echo '== C1. late ritual: 3 days ago ok (late), 8 days ago and tomorrow fail, cannot edit it later'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.rituals (day, kind, result, next_action)
  values ((now() at time zone 'Asia/Seoul')::date - 3, 'close', '늦게 정리', '다음엔 제때')
  returning (created_at at time zone 'Asia/Seoul')::date > day as is_late;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.rituals (day, kind, strength, action) values ((now() at time zone 'Asia/Seoul')::date - 8, 'open', 'x', 'y');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.rituals (day, kind, strength, action) values ((now() at time zone 'Asia/Seoul')::date + 1, 'open', 'x', 'y');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.rituals set result = 'edit' where day < (now() at time zone 'Asia/Seoul')::date - 1 returning day;
rollback;

\echo '== C2. help requests: student asks; other student cannot see; teacher answers as self only'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.help_requests (question) values ('T03 제출이 안 돼요') returning question, answer is null as unanswered;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000e', true);
select count(*) as lee_sees from public.help_requests;
update public.help_requests set answer = 'hack', answered_by = '00000000-0000-0000-0000-00000000000e' returning id;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.help_requests set answer = '자문자답', answered_by = '00000000-0000-0000-0000-00000000000b' returning id;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.help_requests set answer = 'x', answered_by = '00000000-0000-0000-0000-00000000000a';
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.help_requests set answer = '주소 칸에 https:// 를 넣어 주세요', answered_by = '00000000-0000-0000-0000-00000000000c', answered_at = now() returning answer;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.help_requests (question) values ('강사 질문');
rollback;
