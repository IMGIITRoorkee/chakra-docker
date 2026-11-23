#!/bin/bash
# Shared by every ops script: server-local config, required values, the AWS CLI and timestamped logs.

CHAKRA_OPS_HOME=$HOME/chakra-ops                          # installed copy of ops/ on each server
CHAKRA_OPS_ENV=${CHAKRA_OPS_ENV:-$CHAKRA_OPS_HOME/ops.env}  # server-local values kept out of the repo

die() { echo "chakra-ops: $*" >&2; exit 1; }

load_config() {
  [ -r "$CHAKRA_OPS_ENV" ] || die "config $CHAKRA_OPS_ENV not found; create it from ops/ops.env.example"
  # shellcheck source=/dev/null
  . "$CHAKRA_OPS_ENV"
}

require_vars() {
  local var
  for var in "$@"; do
    [ -n "${!var:-}" ] || die "$var is not set in $CHAKRA_OPS_ENV (see ops/ops.env.example)"
  done
}

require_aws() {  # sets AWS to the configured CLI as an array, so it also runs under nice and ionice
  require_vars AWS_BIN AWS_REGION
  # shellcheck disable=SC2034  # used by the sourcing script
  AWS=("$AWS_BIN" --region "$AWS_REGION")
}

log_line() {  # log_line <file> <message...>
  local file=$1; shift
  echo "$(date -u +%FT%TZ) $*" >> "$file"
}
