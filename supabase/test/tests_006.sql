\echo '== K1. admin creates class with park as teacher; teacher/student cannot create; non-teacher cannot be assigned'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
insert into public.classes (name, starts_on, teacher_id) values ('대전 C반', current_date + 10, '00000000-0000-0000-0000-00000000000c') returning name;
insert into public.classes (name, starts_on) values ('서울 A반', current_date - 30) returning name;
commit;
select id as cls from public.classes where name = '대전 C반' \gset
select id as cls2 from public.classes where name = '서울 A반' \gset
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
insert into public.classes (name, starts_on, teacher_id) values ('학생담당반', current_date, '00000000-0000-0000-0000-00000000000b');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.classes (name, starts_on) values ('강사반', current_date);
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select count(*) as student_sees_classes from public.classes;
update public.classes set name = 'hack' returning id;
rollback;

\echo '== K2. student requests (status forced pending); cannot self-approve; one class only'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.class_members (class_id) values (:cls) returning status;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
insert into public.class_members (class_id, status) values (:cls, 'approved');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
update public.class_members set status = 'approved', decided_by = '00000000-0000-0000-0000-00000000000b' returning status;
insert into public.class_members (class_id) values (:cls2);
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000e', true);
insert into public.class_members (class_id) values (:cls2) returning status;
commit;

\echo '== K3. choi (not this class teacher) cannot approve; park approves kim; park cannot approve lee (other class); admin can'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', true);
update public.class_members set status = 'approved', decided_by = '00000000-0000-0000-0000-00000000000d', decided_at = now() returning student_id;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.class_members set status = 'approved', decided_by = '00000000-0000-0000-0000-00000000000a', decided_at = now() where class_id = :cls;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
update public.class_members set status = 'approved', decided_by = '00000000-0000-0000-0000-00000000000c', decided_at = now() where class_id = :cls returning status;
update public.class_members set status = 'approved', decided_by = '00000000-0000-0000-0000-00000000000c', decided_at = now() where class_id = :cls2 returning status;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
update public.class_members set status = 'rejected', decided_by = '00000000-0000-0000-0000-00000000000a', decided_at = now() where class_id = :cls2 returning status;
commit;

\echo '== K4. approved student cannot cancel; rejected student can cancel and re-request'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
delete from public.class_members returning class_id;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000e', true);
delete from public.class_members returning status;
insert into public.class_members (class_id) values (:cls) returning status;
commit;

\echo '== K5. class notices: park writes for own class only; approved kim reads; pending lee does not; choi cannot write'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.class_notices (class_id, body) values (:cls, '첫 수업에 노트북을 챙겨 오세요') returning body;
commit;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
insert into public.class_notices (class_id, body) values (:cls2, '남의 반 공지');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', true);
insert into public.class_notices (class_id, body) values (:cls, '다른 강사');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', true);
delete from public.class_notices returning id;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
select count(*) as kim_reads from public.class_notices;
insert into public.class_notices (class_id, body) values (:cls, '학생 공지');
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000e', true);
select count(*) as pending_lee_reads from public.class_notices;
rollback;

\echo '== K6. deleting a class removes its requests and notices (admin only)'
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
delete from public.classes returning id;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
delete from public.classes where id = :cls returning name;
select count(*) as members_left from public.class_members;
select count(*) as notices_left from public.class_notices;
rollback;
