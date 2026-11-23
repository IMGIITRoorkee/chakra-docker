#!/bin/bash
# Snapshot, lock and verify the server-only config that deploys and builds must never change.
# Edit one: chakra-env-guard.sh unlock; edit; chakra-env-guard.sh snapshot; chakra-env-guard.sh lock
set -euo pipefail
# shellcheck source=ops/lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh" || exit 1

D=$HOME/chakra-docker
BACKUP=$HOME/chakra-env-backup
MANIFEST=$BACKUP/manifest.sha256

load_config
require_vars BACKUP_BUCKET GUARD_S3_PREFIX
require_aws
S3=$BACKUP_BUCKET/$GUARD_S3_PREFIX
LOCKED=(
  "$D/docker-compose.override.yml" /etc/nginx/sites-enabled/chakra.conf /etc/nginx/conf.d/includes/redirect.conf /etc/nginx/conf.d/includes/iitr-only.conf
  "$D/postgres/database.env" "$D/rabbitmq/message_broker.env"
  "$D/codebase/chakra-backend/chakra_backend/.env" "$D/codebase/chakra-backend/supervisor.d/supervisord.conf"
  "$D/codebase/chakra-frontend/.env.local" "$D/codebase/chakra-core/.env"
  "$HOME/chakra-core-start.sh" "$HOME/chakra-core-libraryconfig.json"
)
# Checked, not locked: git must still update components.json.
read -ra TRACKED <<< "$D/codebase/chakra-core/components.json ${GUARD_EXTRA_TRACKED:-}"

case "${1:-}" in
  snapshot)
    ts=$(date +%Y%m%d-%H%M%S); dir=$BACKUP/$ts
    mkdir -p "$dir"; chmod 700 "$BACKUP"
    for f in "${LOCKED[@]}" "${TRACKED[@]}"; do sudo cp -p --parents "$f" "$dir/"; done
    sudo chown -R "$USER": "$dir"
    sha256sum "${LOCKED[@]}" "${TRACKED[@]}" > "$MANIFEST"
    tar -C "$BACKUP" -czf "$BACKUP/$ts.tgz" "$ts" && "${AWS[@]}" s3 cp --quiet --sse AES256 "$BACKUP/$ts.tgz" "$S3/$ts.tgz"
    echo "snapshot $dir (uploaded to $S3/$ts.tgz)";;
  lock)   sudo chattr +i "${LOCKED[@]}"; echo "locked ${#LOCKED[@]} files";;
  unlock) sudo chattr -i "${LOCKED[@]}"; echo "unlocked";;
  check)  sha256sum --quiet -c "$MANIFEST";;
  *) echo "usage: $0 snapshot|lock|unlock|check" >&2; exit 2;;
esac
