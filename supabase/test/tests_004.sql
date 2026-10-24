\echo '== S0. second student (lee)'
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000e', 'lee@aleph.local', '{"userid":"lee","name":"이학생","role":"student"}');

\echo '== S1. everyone logged in reads 13 assignments; anon cannot'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select count(*) as assignments from public.assignments;
rollback;
begin;
set local role anon;
select count(*) from public.assignments;
rollback;

\echo '== S2. student submits current assignment (1); not a later one; needs a url; cannot set status'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.submissions (assignment_no, result_url) values (1, 'https://kim.example/t01') returning assignment_no, status;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.submissions (assignment_no, result_url) values (2, 'https://kim.example/t02');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.submissions (assignment_no, memo) values (1, 'no url');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.submissions (assignment_no, result_url, status) values (1, 'https://x.example', 'approved');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.submissions (assignment_no, result_url) values (1, 'javascript:alert(1)');
rollback;

\echo '== S3. teacher cannot submit; student cannot change status'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.submissions (assignment_no, result_url) values (1, 'https://park.example');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.submissions set status = 'approved' returning id;
rollback;

\echo '== S4. other student sees none of kim''s; teacher and admin see them'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000e', true);
select count(*) as lee_sees from public.submissions;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
select count(*) as teacher_sees from public.submissions;
rollback;

\echo '== S5. teacher checks but cannot approve; admin approves -> kim may submit assignment 2'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.submissions set status = 'approved' where assignment_no = 1;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.submissions set status = 'checked' where assignment_no = 1 returning status;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
update public.submissions set status = 'approved' where assignment_no = 1 returning status;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.submissions (assignment_no, source_url) values (2, 'https://github.com/kim/t02') returning assignment_no;
insert into public.submissions (assignment_no, result_url) values (1, 'https://kim.example/again');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.submissions set status = 'returned' where assignment_no = 1 returning id;
rollback;

\echo '== S6. rituals: student writes today (KST); one per kind per day; only own; teacher reads'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.rituals (kind, strength, action) values ('open', '꼼꼼함', 'T02 질문 세 개 만들기')
  returning kind, day = (now() at time zone 'Asia/Seoul')::date as is_kst_today;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.rituals (kind, strength, action) values ('open', 'x', 'y');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.rituals (kind, strength) values ('close', 'missing');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.rituals set action = 'T02 질문 다섯 개' where kind = 'open' returning action;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000e', true);
select count(*) as lee_sees_rituals from public.rituals;
update public.rituals set action = 'hack' returning action;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
select count(*) as teacher_sees_rituals from public.rituals;
insert into public.rituals (kind, strength, action) values ('open', 'x', 'y');
rollback;

\echo '== S7. yesterday''s ritual cannot be edited'
update public.rituals set day = day - 1;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.rituals set action = 'late' returning action;
rollback;
