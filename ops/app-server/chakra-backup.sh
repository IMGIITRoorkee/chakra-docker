#!/bin/bash
# Chakra backups to the versioned backup bucket (old versions expire after 90 days).
# Usage: chakra-backup.sh db | files
set -euo pipefail
# shellcheck source=ops/lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh" || exit 1

CODEBASE=$HOME/chakra-docker/codebase/chakra-backend
LOCAL_DB_DIR=$HOME/backups-local/db          # last few dumps for fast restores
LOCAL_DB_KEEP=7                              # dumps kept locally
MIN_DUMP_BYTES=1000000                       # smaller than this means the dump is broken
LOG=$HOME/backups-local/backup.log

load_config
require_vars BACKUP_BUCKET
require_aws
AWS+=(--only-show-errors)

mkdir -p "$LOCAL_DB_DIR"
log() { log_line "$LOG" "$@"; }
trap 'log "FAILED: $0 $* (line $LINENO)"' ERR

backup_db() {
  # shellcheck source=/dev/null
  source "$HOME/chakra-docker/postgres/database.env"
  local stamp; stamp=$(date -u +%Y-%m-%dT%H%MZ)
  local file="$LOCAL_DB_DIR/chakradb-$stamp.sql.gz"
  docker exec chakra-docker_database_1 pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$file"
  local size; size=$(stat -c %s "$file")
  [ "$size" -ge "$MIN_DUMP_BYTES" ] || { log "FAILED: dump too small ($size bytes)"; exit 1; }
  "${AWS[@]}" s3 cp "$file" "$BACKUP_BUCKET/db/$(date -u +%Y/%m)/chakradb-$stamp.sql.gz"
  # shellcheck disable=SC2012  # dump names are fixed-format, ls sorts by time
  ls -1t "$LOCAL_DB_DIR"/chakradb-*.sql.gz | tail -n +$((LOCAL_DB_KEEP + 1)) | xargs -r rm -f
  log "db ok $stamp $size bytes"
}

backup_files() {
  local dir
  for dir in website/XML website/HTML website/JoshUsers reverse_proxy_configurations; do
    ionice -c3 nice -n19 "${AWS[@]}" s3 sync "$CODEBASE/$dir/" "$BACKUP_BUCKET/files/$dir/"
  done
  ionice -c3 nice -n19 "${AWS[@]}" s3 sync "$CODEBASE/media_files/" "$BACKUP_BUCKET/files/media_files/" --exclude "preview/*"
  log "files ok"
}

case "${1:-}" in
  db) backup_db ;;
  files) backup_files ;;
  *) echo "usage: $0 db|files" >&2; exit 2 ;;
esac
date -u +%FT%TZ | "${AWS[@]}" s3 cp - "$BACKUP_BUCKET/status/last-success-${1}.txt"
