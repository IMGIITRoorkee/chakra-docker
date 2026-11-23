#!/bin/bash
# Every 5 minutes: check backups are fresh and Chakra's services are up; publish each result to CloudWatch (Chakra/Health).
set -uo pipefail
# shellcheck source=ops/lib/health.sh
. "$(dirname "$(readlink -f "$0")")/../lib/health.sh" || exit 1

BACKUP_LOG=$HOME/backups-local/backup.log
LOG=$HOME/backups-local/health.log
DB_MAX_AGE_H=7      # db dumps run every 6 hours
FILES_MAX_AGE_H=26  # file sync runs daily
DISK_MAX_PCT=85

load_config
require_vars CHAKRA_HOST ROOT2_TUNNEL_PORT
require_aws

age_hours() {  # hours since the last "<kind> ok" line; also reads backup.log.1, since logrotate empties the log daily
  local ts; ts=$(cat "$BACKUP_LOG.1" "$BACKUP_LOG" 2>/dev/null | grep " $1 ok" | tail -1 | cut -d' ' -f1)
  [ -n "$ts" ] && echo $(( ($(date +%s) - $(date -d "$ts" +%s)) / 3600 )) || echo 9999
}

db_age=$(age_hours db); files_age=$(age_hours files)
disk=$(df --output=pcent / | tail -1 | tr -dc 0-9)
# shellcheck disable=SC2034  # read by health_report
declare -A check=(
  [BackupDbFresh]=$([ "$db_age" -le $DB_MAX_AGE_H ] && echo 1 || echo 0)
  [BackupFilesFresh]=$([ "$files_age" -le $FILES_MAX_AGE_H ] && echo 1 || echo 0)
  [DiskOk]=$([ "$disk" -lt $DISK_MAX_PCT ] && echo 1 || echo 0)
  [LsyncdUp]=$(ok systemctl is-active --quiet lsyncd-chakra)
  [Root2TunnelUp]=$(ok bash -c "ss -ltn | grep -q '127.0.0.1:$ROOT2_TUNNEL_PORT '")
  [BackendUp]=$(http_ok -H "Host: $CHAKRA_HOST" http://127.0.0.1:8000/admin/login/)
  [FrontendUp]=$(http_ok http://127.0.0.1:3000/login/)
  [TranspilerUp]=$(http_ok http://127.0.0.1:5000/health)
  [ConfigUnchanged]=$(ok "$HOME/chakra-env-guard.sh" check)
  [CeleryUp]=$(ok bash -c 'docker top chakra-docker_chakra-backend_1 | grep -q "celery -A chakra_backend worker"')
  [SiteUp]=$(http_ok -k --resolve "$CHAKRA_HOST:443:127.0.0.1" "https://$CHAKRA_HOST/login/")
)
health_report "$LOG" "db_age_h=$db_age files_age_h=$files_age disk=${disk}%" \
  BackupDbAgeHours="$db_age" BackupFilesAgeHours="$files_age"
