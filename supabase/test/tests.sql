\set ON_ERROR_STOP 0
\echo '== 1. student signup'
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000a', 'admin@aleph.local', '{"userid":"admin","name":"관리자","role":"student"}');
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000b', 'kim@aleph.local', '{"userid":"kim","name":"김학생","role":"student","extra":{"grade":"high"}}');
\echo '== 2. admin role via sql editor, then signup as admin must fail'
update public.profiles set role = 'admin' where userid = 'admin';
insert into auth.users (email, raw_user_meta_data) values ('hack@aleph.local', '{"userid":"hack","name":"x","role":"admin"}');
\echo '== 3. teacher signup with no/invalid code must fail'
insert into auth.users (email, raw_user_meta_data) values ('t0@aleph.local', '{"userid":"t0","name":"x","role":"teacher"}');
insert into auth.users (email, raw_user_meta_data) values ('t1@aleph.local', '{"userid":"t1","name":"x","role":"teacher","teacher_code":"NOPE"}');

\echo '== 4. student cannot read or issue codes'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select count(*) as student_sees_codes from public.teacher_codes;
insert into public.teacher_codes default values;
rollback;

\echo '== 5. admin issues a code'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
insert into public.teacher_codes default values returning length(code) as code_len, created_by;
commit;
select code as issued from public.teacher_codes \gset

\echo '== 6. teacher signup with lowercase+spaces code succeeds'
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000c', 'park@aleph.local',
  json_build_object('userid','park','name','박강사','role','teacher','teacher_code', ' ' || lower(:'issued') || ' ')::jsonb);
select userid, role from public.profiles where userid = 'park';
select used_by is not null as used from public.teacher_codes;
\echo '== 7. same code again must fail'
insert into auth.users (email, raw_user_meta_data) values ('lee@aleph.local',
  json_build_object('userid','lee','name','x','role','teacher','teacher_code', :'issued')::jsonb);

\echo '== 8. teacher login code check (own code true, wrong false, other user false)'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
select public.verify_teacher_code(:'issued') as own_ok, public.verify_teacher_code('WRONG') as wrong;
select count(*) as teacher_sees_codes from public.teacher_codes;
select count(*) as teacher_sees_profiles from public.profiles;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select public.verify_teacher_code(:'issued') as student_using_teacher_code;
rollback;

\echo '== 9. anon cannot call verify or read'
begin;
set local role anon;
select public.verify_teacher_code('x');
rollback;
begin;
set local role anon;
select count(*) from public.profiles;
rollback;

\echo '== 10. admin: used code cannot be deleted, unused can; admin sees profiles + embed'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
delete from public.teacher_codes where used_by is not null returning code;
insert into public.teacher_codes default values;
delete from public.teacher_codes where used_by is null returning 'deleted unused' as r;
select count(*) as admin_sees_profiles from public.profiles;
select t.used_at is not null as used, p.name from public.teacher_codes t left join public.profiles p on p.id = t.used_by;
commit;

\echo '== 11. profile update by user must be blocked (role escalation)'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.profiles set role = 'admin' where userid = 'kim';
rollback;
select userid, role from public.profiles order by userid;
