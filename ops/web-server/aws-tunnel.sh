#!/bin/bash
# Reverse SSH tunnel so the Chakra app server can reach this host (its lsyncd target) on its 127.0.0.1:ROOT2_TUNNEL_PORT.
set -uo pipefail
# shellcheck source=ops/lib/reverse-tunnel.sh
. "$(dirname "$(readlink -f "$0")")/../lib/reverse-tunnel.sh" || exit 1

load_config
require_vars ROOT2_TUNNEL_PORT ROOT2_TUNNEL_DEST ROOT2_TUNNEL_KEY
reverse_tunnel /tmp/aws-tunnel.lock "$HOME/aws-tunnel.log" \
  "127.0.0.1:$ROOT2_TUNNEL_PORT:127.0.0.1:22" "$ROOT2_TUNNEL_DEST" -i "$ROOT2_TUNNEL_KEY"
