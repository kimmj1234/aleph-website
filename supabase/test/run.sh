#!/usr/bin/env bash
# setup.sql 이 의도대로 동작하는지 진짜 Postgres 에서 확인 (Docker 필요, Supabase 프로젝트는 필요 없음)
# 실행: bash supabase/test/run.sh   → 결과의 각 단계 설명대로 성공/실패하면 정상
set -e
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
docker rm -f aleph-pg-test >/dev/null 2>&1 || true
docker run -d --name aleph-pg-test -e POSTGRES_PASSWORD=test -v "$PWD:/work" postgres:18 >/dev/null
until docker exec aleph-pg-test pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done; sleep 2
docker exec aleph-pg-test psql -U postgres -q -v ON_ERROR_STOP=1 -f /work/test/00_fake_supabase.sql -f /work/setup.sql -f /work/002_dashboard.sql -f /work/003_teacher.sql -f /work/004_student.sql -f /work/005_cortex.sql -f /work/006_classes.sql -f /work/007_ritual_all.sql
docker exec aleph-pg-test psql -U postgres -f /work/test/tests.sql -f /work/test/tests_002.sql -f /work/test/tests_003.sql -f /work/test/tests_004.sql -f /work/test/tests_005.sql -f /work/test/tests_006.sql -f /work/test/tests_007.sql 2>&1 || true
docker rm -f aleph-pg-test >/dev/null
