\echo '== R1. teacher writes own practice ritual; cannot write for a student; student still cannot read it'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.rituals (kind, strength, action) values ('open', '차분함', '수업 전 체험') returning kind;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.rituals (student_id, kind, strength, action) values ('00000000-0000-0000-0000-00000000000b', 'close', 'x', 'y');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000e', true);
select count(*) as lee_sees_teacher_ritual from public.rituals where student_id = '00000000-0000-0000-0000-00000000000c';
rollback;
\echo '== R2. admin writes own practice ritual'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
insert into public.rituals (kind, result, next_action) values ('close', '체험 완료', '학생에게 안내') returning kind;
rollback;
