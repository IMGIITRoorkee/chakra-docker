#!/bin/bash
# Applies root2's nginx config (pushed to /home/root2/nginx-incoming) on this replica, keeping the last good one.
# nginx here is newer than root2's, so the obsolete "ssl on;" line is dropped; every such block already listens with ssl.
set -uo pipefail

IN=/home/root2/nginx-incoming
GOOD=/var/lib/replica-nginx/last-good
LOG=/var/log/replica-nginx-apply.log

exec 9>/run/replica-nginx-apply.lock; flock 9
log(){ echo "$(date -u +%FT%TZ) $*" >> "$LOG"; }
mirror() { rsync -a --delete --exclude /modules-enabled/ --exclude /modules-available/ "$1" "$2"; }  # keeps this host's modules

[ -f "$IN/nginx.conf" ] || { log "skip: no incoming config"; exit 0; }
mkdir -p "$GOOD"
mirror /etc/nginx/ "$GOOD/"
mirror "$IN/" /etc/nginx/
grep -rlZE '^\s*ssl\s+on\s*;' /etc/nginx | xargs -0 -r sed -i -E '/^\s*ssl\s+on\s*;/d'
chown -R root2:root2 /etc/nginx
if out=$(nginx -t 2>&1); then
  systemctl reload nginx && log "applied and reloaded"
else
  mirror "$GOOD/" /etc/nginx/
  log "REJECTED, kept last good config: $(echo "$out" | grep -m1 emerg)"
  exit 1
fi
