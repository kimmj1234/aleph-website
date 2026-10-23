\echo '== T0. second teacher (choi) for isolation checks'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
insert into public.teacher_codes default values returning code as code2 \gset
commit;
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000d', 'choi@aleph.local',
  json_build_object('userid','choi','name','최강사','role','teacher','teacher_code', :'code2')::jsonb);

\echo '== T1. teacher edits own profile; cannot edit others or own role'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.profiles set name = '박선생', bio = '파이썬 담당', subjects = '{python,data}' where userid = 'park' returning name, bio, subjects;
update public.profiles set bio = 'x' where userid = 'kim' returning userid;
update public.profiles set bio = 'x' where userid = 'choi' returning userid;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.profiles set role = 'admin' where userid = 'park';
rollback;

\echo '== T2. student cannot edit own profile'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.profiles set bio = 'hi' where userid = 'kim' returning userid;
rollback;

\echo '== T3. teacher reads students (+self) only; student still only self'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
select string_agg(userid, ',' order by userid) as teacher_sees from public.profiles;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select string_agg(userid, ',' order by userid) as student_sees from public.profiles;
rollback;

\echo '== T4. memos: teacher writes on student, not on teacher; others cannot see'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.student_notes (student_id, note) values ('00000000-0000-0000-0000-00000000000b', '수학 기초 보충 필요') returning note;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.student_notes (student_id, note) values ('00000000-0000-0000-0000-00000000000d', '강사에게 메모');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', true);
select count(*) as other_teacher_sees from public.student_notes;
update public.student_notes set note = 'hack' returning note;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select count(*) as student_sees_notes from public.student_notes;
insert into public.student_notes (student_id, note) values ('00000000-0000-0000-0000-00000000000b', 'self');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
select count(*) as admin_sees_notes from public.student_notes;
rollback;

\echo '== T5. owner updates and deletes memo'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.student_notes set note = '보충 완료', updated_at = now() where student_id = '00000000-0000-0000-0000-00000000000b' returning note;
delete from public.student_notes returning 'deleted' as r;
commit;
