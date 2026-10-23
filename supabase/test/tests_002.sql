\echo '== D1. everyone logged in reads notices; anon cannot'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
insert into public.notices (title, pinned) values ('관리자 공지', true) returning title, pinned, created_by is not null as has_author;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select count(*) as student_reads_notices from public.notices;
rollback;
begin;
set local role anon;
select count(*) from public.notices;
rollback;

\echo '== D2. student and teacher cannot write notices'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.notices (title) values ('학생 글');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.notices set title = '강사 수정' returning id;
delete from public.notices returning id;
rollback;

\echo '== D3. admin edits and deletes notices; cannot forge created_at'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
update public.notices set title = '수정된 공지', pinned = false returning title, pinned;
insert into public.notices (title, created_at) values ('x', now());
rollback;

\echo '== D4. admin renames a member; cannot change role/userid; student cannot rename'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
update public.profiles set name = '김학생2' where userid = 'kim' returning name;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
update public.profiles set role = 'admin' where userid = 'kim';
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.profiles set name = 'hack' where userid = 'park' returning name;
update public.profiles set name = 'me' where userid = 'kim' returning name;
rollback;
select userid, name, role from public.profiles order by userid;
