#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")"
test "${#JWT_SECRET_KEY}" -ge 32
test -n "$DB_USER" && test -n "$DB_PASSWORD" && test -n "$DB_NAME"
test "$(git rev-parse HEAD)" = "$DEPLOY_SHA"
command -v curl >/dev/null
command -v python3 >/dev/null
docker compose version >/dev/null

project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' camphub-postgres)
test -n "$project"
test "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' camphub-fastapi)" = "$project"
db_volume=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' camphub-postgres)
test -n "$db_volume"
export COMPOSE_PROJECT_NAME="$project"
network=$(docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}}{{end}}' camphub-fastapi)
docker network inspect "$network" >/dev/null
backup="$HOME/.local/state/sirius-hub/$(date -u +%Y%m%dT%H%M%SZ)-${DEPLOY_SHA:0:12}"
mkdir -p "$backup"
chmod 700 "$backup"
test ! -e .env || cp -p .env "$backup/previous.env"
docker inspect camphub-fastapi camphub-postgres >"$backup/containers.json"
cp docker-compose.yml "$backup/candidate-compose.yml"

python3 - <<'PY'
import json
import os
from pathlib import Path

keys = ("JWT_SECRET_KEY", "DB_USER", "DB_PASSWORD", "DB_NAME")
text = "".join(
    f"{key}={json.dumps(os.environ[key].replace('$', '$$'), ensure_ascii=False)}\n"
    for key in keys
)
config = Path(".env")
config.write_text(text)
config.chmod(0o600)
PY
docker compose config --quiet
candidate_volume=$(docker compose config --format json | python3 -c 'import json, sys; print(json.load(sys.stdin)["volumes"]["postgres_data"]["name"])')
test "$candidate_volume" = "$db_volume"
docker compose build api

sql() {
  docker exec camphub-postgres sh -c 'exec psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<<"$1"
}
revision=$(sql 'SELECT version_num FROM alembic_version')
case "$revision" in
  5a1e237bc965|821a1b366db6) ;;
  *) echo 'Unexpected database migration version'; exit 1 ;;
esac
test "$(sql 'SELECT count(*) FROM (SELECT lower(email) FROM users WHERE email IS NOT NULL GROUP BY lower(email) HAVING count(*) > 1) AS duplicates')" = 0
docker compose run --rm --no-deps api python -c 'import asyncio; from database.database import engine; from sqlalchemy import text; exec("async def check():\n async with engine.connect() as c: await c.execute(text(\"SELECT 1\"))\n await engine.dispose()"); asyncio.run(check())'

stopped=false
candidate_started=false
rollback_image="sirius-hub-rollback:${DEPLOY_SHA:0:12}-$(date -u +%s)"
rollback() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ] && [ "$stopped" = true ]; then
    if [ "$candidate_started" = true ]; then
      docker rm -f camphub-fastapi >/dev/null 2>&1 || true
      docker run -d --name camphub-fastapi --restart always --network "$network" \
        --network-alias api -p 127.0.0.1:56284:8000 \
        -v "$(pwd)/uploads:/app/uploads" "$rollback_image" >/dev/null
    else
      docker start camphub-fastapi >/dev/null
    fi
    echo 'Deployment failed. Previous API restored. Database was not downgraded.'
    echo "Private recovery files: $backup"
  fi
  exit "$status"
}
trap rollback EXIT
docker stop camphub-fastapi >/dev/null
stopped=true
docker exec camphub-postgres sh -c 'exec pg_dump -Fc -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >"$backup/database.dump"
test -s "$backup/database.dump"
docker exec -i camphub-postgres pg_restore --list <"$backup/database.dump" >"$backup/database.contents"
identity_sql="SELECT md5(coalesce(string_agg(((to_jsonb(u) - 'hashed_password' - 'is_active') || jsonb_build_object('role', coalesce(role, 'student')))::text, ',' ORDER BY id), '')) FROM users u"
sql "$identity_sql" >"$backup/accounts.before"
docker cp camphub-fastapi:/app/uploads "$backup/uploads"
mkdir -p uploads
cp -a "$backup/uploads/." uploads/
tar -C "$backup" -czf "$backup/uploads.tar.gz" uploads
docker commit camphub-fastapi "$rollback_image" >/dev/null
printf '%s\n' "$rollback_image" >"$backup/rollback-image"
docker image inspect "$rollback_image" >/dev/null

docker compose up -d db
test "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' camphub-postgres)" = "$db_volume"
candidate_started=true
docker compose up -d --no-deps api
ready=false
for attempt in $(seq 1 60); do
  if curl --fail --silent --max-time 3 http://127.0.0.1:56284/openapi.json >"$backup/openapi.json"; then
    ready=true
    break
  fi
  sleep 2
done
test "$ready" = true
python3 - "$backup/openapi.json" <<'PY'
import json
import sys

paths = json.load(open(sys.argv[1]))["paths"]
assert all(path in paths for path in ("/auth/register", "/auth/token", "/auth/me"))
assert "/auth/init" not in paths
assert "/auth/test-make-me-council" not in paths
PY
test "$(sql 'SELECT version_num FROM alembic_version')" = 821a1b366db6
sql "$identity_sql" >"$backup/accounts.after"
cmp "$backup/accounts.before" "$backup/accounts.after"
test "$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 10 https://104.143.201.57/auth/me)" = 401
docker inspect --format '{{.Image}}' camphub-fastapi >"$backup/deployed-image"
printf '%s\n' "$DEPLOY_SHA" >"$backup/deployed-commit"
trap - EXIT
echo "Deployment ready: $DEPLOY_SHA, schema 821a1b366db6"
echo "Private recovery files: $backup"
