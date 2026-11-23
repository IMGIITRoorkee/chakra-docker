#!/bin/bash
# Pushes this server's nginx config to the AWS replica, which applies it itself. Read-only here.
set -uo pipefail
# shellcheck source=ops/lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh" || exit 1

LOG=$HOME/replica-sync/push-nginx.log

load_config
require_vars REPLICA_PUSH_DEST REPLICA_PUSH_KEY
exec 9>/tmp/replica-push-nginx.lock; flock -n 9 || exit 0
rsync -a --delete -e "ssh -i $REPLICA_PUSH_KEY -o BatchMode=yes -o ConnectTimeout=15" \
  /etc/nginx/ "$REPLICA_PUSH_DEST:/home/root2/nginx-incoming/" \
  && ssh -i "$REPLICA_PUSH_KEY" -o BatchMode=yes "$REPLICA_PUSH_DEST" "date -u +%FT%TZ > /home/root2/.nginx-push-ok"
rc=$?
[ "$rc" = 0 ] || log_line "$LOG" "push failed rc=$rc"
