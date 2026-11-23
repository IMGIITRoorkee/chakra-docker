#!/bin/bash
# Installs one server role's scripts, cron entries, systemd units and logrotate files. Safe to re-run.
# Usage: install.sh <role> [--dry-run]
set -euo pipefail

OPS_SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROLES=(app-server replica web-server jump-host staging)
CWAGENT_CTL=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
CWAGENT_CONFIG=/opt/aws/amazon-cloudwatch-agent/etc/chakra-cloudwatch.json
FSTAB=/etc/fstab
PRE_OPS_SUFFIX=.pre-ops  # a file replaced by a link is kept under this suffix
DRY_RUN=0
# shellcheck source=ops/lib/common.sh
. "$OPS_SRC/lib/common.sh"

dry() { [ "$DRY_RUN" = 1 ]; }
say() { printf '%-6s %s\n' "$1" "$2"; }

render() {  # prints a template with each ${VAR} taken from the config; fails on a missing one
  local text var
  text=$(<"$1")
  # shellcheck disable=SC2016
  for var in $(grep -o '\${[A-Z_][A-Z0-9_]*}' "$1" | tr -d '${}' | sort -u); do
    require_vars "$var"
    text=${text//"\${$var}"/"${!var}"}
  done
  printf '%s\n' "$text"
}

script_vars() {  # the config values a script requires, read from its require_vars and require_aws lines
  sed -n 's/^require_vars //p' "$1"
  if grep -q '^require_aws' "$1"; then echo AWS_BIN AWS_REGION; fi
}

file_status() {
  if [ ! -e "$2" ]; then echo new
  elif cmp -s "$1" "$2"; then echo unchanged
  else echo changed; fi
}

sync_tree() {
  say sync "$OPS_SRC -> $CHAKRA_OPS_HOME"
  dry && return 0
  mkdir -p "$CHAKRA_OPS_HOME"
  rsync -a --delete --exclude /ops.env "$OPS_SRC/" "$CHAKRA_OPS_HOME/"
}

# link <source> <server path>: the server path becomes a symlink into the installed copy.
link() {
  local target=$CHAKRA_OPS_HOME/$1 path=$2 status=new
  # shellcheck disable=SC2046
  [[ $1 != *.sh ]] || require_vars $(script_vars "$OPS_SRC/$1")
  if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then status=unchanged
  elif [ -e "$path" ] || [ -L "$path" ]; then status="replaced, old file kept as $path$PRE_OPS_SUFFIX"; fi
  say link "$path -> $target ($status)"
  if [ "$status" = unchanged ] || dry; then return 0; fi
  mkdir -p "$(dirname "$path")"
  if [ "$status" != new ]; then mv "$path" "$path$PRE_OPS_SUFFIX"; fi
  ln -s "$target" "$path"
}

# put <source> <server path> <mode> <owner:group> [command to run when it changed...]
put() {
  local src=$OPS_SRC/$1 dest=$2 mode=$3 owner=$4 status; shift 4
  if [[ $src == *.tmpl ]]; then render "$src" > "$WORK/$(basename "$src")"; src=$WORK/$(basename "$src"); fi
  status=$(file_status "$src" "$dest")
  say put "$dest ($status)${1:+, then $*}"
  if [ "$status" = unchanged ] || dry; then return 0; fi
  sudo mkdir -p "$(dirname "$dest")"
  sudo install -m "$mode" -o "${owner%:*}" -g "${owner#*:}" "$src" "$dest"
  "$@"
}

merged_crontab() {  # merged_crontab <role> <entries file>: the crontab with the role's block replaced and old copies of its entries dropped
  local begin="# BEGIN chakra-ops $1" end="# END chakra-ops $1"
  { crontab -l 2>/dev/null || true; } | sed "/^$begin\$/,/^$end\$/d" | { grep -vxF -f "$2" || true; }
  echo "$begin"; cat "$2"; echo "$end"
}

install_cron() {
  local src=$OPS_SRC/$1/crontab.tmpl status=changed
  render "$src" > "$WORK/cron.entries"
  merged_crontab "$1" "$WORK/cron.entries" > "$WORK/crontab"
  if { crontab -l 2>/dev/null || true; } | cmp -s - "$WORK/crontab"; then status=unchanged; fi
  say cron "$(wc -l < "$WORK/cron.entries" | tr -d ' ') entries in the chakra-ops $1 block ($status)"
  sed 's/^/         /' "$WORK/cron.entries"
  if [ "$status" = unchanged ] || dry; then return 0; fi
  crontab "$WORK/crontab"
}

install_fstab_line() {  # appends the rendered line unless its mount point is already in fstab
  local line mount_point
  line=$(render "$OPS_SRC/$1"); mount_point=$(awk '{print $2}' <<<"$line")
  if grep -qsxF "$line" "$FSTAB"; then say fstab "$mount_point (unchanged)"; return 0; fi
  if awk -v m="$mount_point" '$2 == m {found = 1} END {exit !found}' "$FSTAB" 2>/dev/null; then
    say fstab "$mount_point (another entry exists, left as is)"; return 0
  fi
  say fstab "$mount_point (new), then mount it"
  dry && return 0
  echo "$line" | sudo tee -a "$FSTAB" >/dev/null
  sudo mkdir -p "$mount_point"
  sudo mount "$mount_point"
}

restart_unit() { sudo systemctl daemon-reload && sudo systemctl enable "$1" && sudo systemctl restart "$1"; }
reload_cwagent() { sudo "$CWAGENT_CTL" -a fetch-config -m ec2 -s -c "file:$CWAGENT_CONFIG"; }

role_app_server() {
  link app-server/chakra-backup.sh "$HOME/chakra-backup/chakra-backup.sh"
  link app-server/chakra-health.sh "$HOME/chakra-backup/chakra-health.sh"
  link app-server/chakra-env-guard.sh "$HOME/chakra-env-guard.sh"
  put app-server/lsyncd-ssh_config.tmpl /etc/lsyncd/ssh_config 644 root:root
  put app-server/lsyncd.conf.lua /etc/lsyncd/lsyncd.conf.lua 644 root:root restart_unit lsyncd-chakra
  put app-server/lsyncd-chakra.service /etc/systemd/system/lsyncd-chakra.service 644 root:root restart_unit lsyncd-chakra
  put app-server/logrotate /etc/logrotate.d/chakra 644 root:root
  put app-server/cloudwatch.json "$CWAGENT_CONFIG" 644 cwagent:cwagent reload_cwagent
  install_cron app-server
}

role_replica() {
  link replica/replica-health.sh "$HOME/chakra-health/replica-health.sh"
  link replica/backup-root2-nginx.sh "$HOME/chakra-health/backup-root2-nginx.sh"
  put replica/replica-nginx-apply.sh /usr/local/sbin/replica-nginx-apply.sh 755 root:root
  put replica/replica-nginx-watch.sh /usr/local/sbin/replica-nginx-watch.sh 755 root:root restart_unit replica-nginx-watch
  put replica/replica-nginx-watch.service /etc/systemd/system/replica-nginx-watch.service 644 root:root restart_unit replica-nginx-watch
  put replica/logrotate /etc/logrotate.d/chakra-replica 644 root:root
  install_fstab_line replica/fstab-s3fs.tmpl
  install_cron replica
}

role_web_server() {
  link web-server/aws-tunnel.sh "$HOME/aws-tunnel.sh"
  link web-server/push-nginx.sh "$HOME/replica-sync/push-nginx.sh"
  install_cron web-server
}

role_jump_host() {
  link jump-host/prod-to-replica.sh "$HOME/chakra/tunnels/prod-to-replica.sh"
  install_cron jump-host
}

role_staging() {
  link app-server/chakra-env-guard.sh "$HOME/chakra-env-guard.sh"
  link staging/refresh-db.sh "$HOME/chakra-staging/refresh-db.sh"
  link staging/counts.sql "$HOME/chakra-staging/counts.sql"
  link staging/mk_html_dirs.py "$HOME/chakra-staging/mk_html_dirs.py"
}

usage() { local IFS="|"; echo "usage: $0 <${ROLES[*]}> [--dry-run]" >&2; exit 2; }

main() {
  local role=${1:-}
  [[ " ${ROLES[*]} " == *" $role "* ]] || usage
  case "${2:-}" in --dry-run) DRY_RUN=1 ;; "") ;; *) usage ;; esac
  load_config
  WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
  say role "$role$(dry && echo ' (dry run)' || true), config $CHAKRA_OPS_ENV"
  sync_tree
  "role_${role//-/_}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
