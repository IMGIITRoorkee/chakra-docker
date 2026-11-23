#!/bin/bash
# Every 5 minutes: check the root2 replica can serve the sites; publish each result to CloudWatch (Chakra/Health).
set -uo pipefail
# shellcheck source=ops/lib/health.sh
. "$(dirname "$(readlink -f "$0")")/../lib/health.sh" || exit 1

LOG=$HOME/chakra-health/health.log
PUSH_OK=/home/root2/.nginx-push-ok  # root2 writes its push time here
DISK_MAX_PCT=85
CONFIG_MAX_AGE_MIN=20               # root2 pushes nginx config every 5 minutes

load_config
require_vars SITE_HOST
require_aws

config_age_min() { local ts; ts=$(cat "$PUSH_OK" 2>/dev/null) && echo $(( ($(date +%s) - $(date -d "$ts" +%s)) / 60 )) || echo 9999; }

disk=$(df --output=pcent / | tail -1 | tr -dc 0-9); cfg_age=$(config_age_min)
# shellcheck disable=SC2034  # read by health_report
declare -A check=(
  [DiskOk]=$([ "$disk" -lt $DISK_MAX_PCT ] && echo 1 || echo 0)
  [NginxUp]=$(ok systemctl is-active --quiet nginx)
  [ReplicaSiteUp]=$(http_ok -k --resolve "$SITE_HOST:443:127.0.0.1" "https://$SITE_HOST/")
  [FacSpaceMounted]=$(ok mountpoint -q /home/root2/s3bucket)
  [ReplicaConfigFresh]=$([ "$cfg_age" -le $CONFIG_MAX_AGE_MIN ] && echo 1 || echo 0)
)
health_report "$LOG" "config_age_min=$cfg_age disk=${disk}%"
