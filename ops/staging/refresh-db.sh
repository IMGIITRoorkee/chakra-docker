#!/bin/bash
# Replaces staging's database with the newest prod dump in the backup bucket (or the key given as $1) and prints row counts.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=ops/lib/common.sh
. "$here/../lib/common.sh" || exit 1

DB=chakra-docker_database_1
RESTORE_DIR=$HOME/restore  # downloaded dumps, reused on the next run

load_config
require_vars BACKUP_BUCKET
require_aws

cd ~/chakra-docker
key=${1:-$("${AWS[@]}" s3 ls "$BACKUP_BUCKET/db/" --recursive | awk '{print $4}' | grep -E 'chakradb-.*\.sql\.gz$' | sort | tail -1)}
dump=$RESTORE_DIR/$(basename "$key")
mkdir -p "$RESTORE_DIR"
[ -f "$dump" ] || "${AWS[@]}" s3 cp --only-show-errors "$BACKUP_BUCKET/$key" "$dump"
gzip -t "$dump"
echo "dump $key $(stat -c %s "$dump") bytes"

docker compose stop chakra-backend chakra_frontend
# shellcheck disable=SC2016
docker exec "$DB" bash -c 'dropdb -U "$POSTGRES_USER" --if-exists "$POSTGRES_DB" && createdb -U "$POSTGRES_USER" -O "$POSTGRES_USER" "$POSTGRES_DB"'
start=$(date +%s)
# shellcheck disable=SC2016
zcat "$dump" | docker exec -i "$DB" bash -c 'psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null
echo "restored in $(( $(date +%s) - start ))s"
# shellcheck disable=SC2016
docker exec -i "$DB" bash -c 'psql -At -F" " -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$here/counts.sql"
docker compose up -d chakra-backend chakra_frontend
sleep 15
docker exec -i chakra-docker_chakra-backend_1 bash -c 'source chakra_backend/.env && python manage.py shell' < "$here/mk_html_dirs.py"
