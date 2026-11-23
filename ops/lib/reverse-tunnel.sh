#!/bin/bash
# Keeps one reverse SSH tunnel up. Cron starts it at boot and every 5 minutes; the lock keeps a single instance.
# shellcheck source=ops/lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh" || exit 1

TUNNEL_RETRY_SEC=10  # pause before reconnecting

# reverse_tunnel <lock file> <log file> <remote forward> <ssh destination> [extra ssh options...]
reverse_tunnel() {
  local lock=$1 log=$2 forward=$3 dest=$4; shift 4
  exec 9>"$lock"
  flock -n 9 || return 0
  while true; do
    ssh -N "$@" -o BatchMode=yes -o ExitOnForwardFailure=yes \
      -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
      -R "$forward" "$dest"
    log_line "$log" "tunnel exited with $?, reconnecting"
    sleep "$TUNNEL_RETRY_SEC"
  done
}
