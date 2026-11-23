#!/bin/bash
# Reverse tunnel: app server 127.0.0.1:REPLICA_TUNNEL_PORT -> replica:22, for the app server's lsyncd (no direct route between the two).
set -uo pipefail
# shellcheck source=ops/lib/reverse-tunnel.sh
. "$(dirname "$(readlink -f "$0")")/../lib/reverse-tunnel.sh" || exit 1

load_config
require_vars REPLICA_TUNNEL_PORT REPLICA_SSH_ADDR APP_SERVER_SSH_DEST
reverse_tunnel /tmp/chakra-prod-to-replica.lock "$HOME/chakra/tunnels/prod-to-replica.log" \
  "127.0.0.1:$REPLICA_TUNNEL_PORT:$REPLICA_SSH_ADDR:22" "$APP_SERVER_SSH_DEST"
