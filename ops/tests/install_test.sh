#!/bin/bash
# shellcheck disable=SC2016  # stub bodies and templates are literal on purpose
# shellcheck source=ops/tests/assert.sh
. "$(dirname "$0")/assert.sh" || exit 1
# shellcheck source=ops/install.sh
. "$OPS/install.sh"
set +eu  # install.sh is strict; the assertions need to see failures

CHAKRA_OPS_ENV=$T/ops.env
CHAKRA_OPS_HOME=$T/installed
WORK=$T/work; mkdir -p "$WORK" "$CHAKRA_OPS_HOME/role"
printf "FOO=one\\nBAR='a/b&c'\\n" > "$CHAKRA_OPS_ENV"
load_config

printf 'x ${FOO} y ${BAR} ${FOO}\n' > "$T/t.tmpl"
assert_eq "render fills every value" "$(render "$T/t.tmpl")" "x one y a/b&c one"
printf '${NOPE}\n' > "$T/bad.tmpl"
out=$(render "$T/bad.tmpl" 2>&1); rc=$?
assert_eq "render fails on a missing value" "$rc:$out" "1:chakra-ops: NOPE is not set in $CHAKRA_OPS_ENV (see ops/ops.env.example)"

printf 'require_vars A B\nrequire_aws\n' > "$T/s.sh"
assert_eq "script_vars reads require lines" "$(script_vars "$T/s.sh" | tr '\n' ' ')" "A B AWS_BIN AWS_REGION "

OPS_SRC=$T/src; mkdir -p "$OPS_SRC/role"
printf 'require_vars FOO\n' > "$OPS_SRC/role/ok.sh"
printf 'require_vars MISSING_ONE\n' > "$OPS_SRC/role/needs.sh"
out=$(link role/needs.sh "$T/srv/needs.sh" 2>&1); rc=$?
assert_eq "link refuses a script whose config is missing" "$rc:$out" "1:chakra-ops: MISSING_ONE is not set in $CHAKRA_OPS_ENV (see ops/ops.env.example)"

DRY_RUN=1 link role/ok.sh "$T/srv/ok.sh" >/dev/null
assert_eq "dry run links nothing" "$([ -e "$T/srv/ok.sh" ] || [ -L "$T/srv/ok.sh" ] && echo made || echo none)" none
link role/ok.sh "$T/srv/ok.sh" >/dev/null
assert_eq "link creates the symlink" "$(readlink "$T/srv/ok.sh")" "$CHAKRA_OPS_HOME/role/ok.sh"
assert_contains "link is idempotent" "$(link role/ok.sh "$T/srv/ok.sh")" "(unchanged)"
echo old > "$T/srv/legacy.sh"
link role/ok.sh "$T/srv/legacy.sh" >/dev/null
assert_eq "link keeps a replaced file" "$(cat "$T/srv/legacy.sh.pre-ops"):$(readlink "$T/srv/legacy.sh")" "old:$CHAKRA_OPS_HOME/role/ok.sh"

stub sudo 'echo "$*" >> "$T/sudo.log"'
echo same > "$OPS_SRC/role/f"; echo same > "$T/f-installed"
assert_contains "put skips an unchanged file" "$(put role/f "$T/f-installed" 644 root:root echo reloaded)" "(unchanged)"
assert_eq "put runs nothing for an unchanged file" "$(cat "$T/sudo.log" 2>/dev/null)" ""
out=$(put role/f "$T/f-new" 644 root:root echo reloaded)
assert_contains "put installs a new file" "$(cat "$T/sudo.log")" "install -m 644 -o root -g root $OPS_SRC/role/f $T/f-new"
assert_contains "put runs the on-change command" "$out" reloaded

stub crontab 'printf "MAILTO=\"\"\n15 * * * * /x/legacy.sh\n# BEGIN chakra-ops role\nstale\n# END chakra-ops role\n"'
printf '15 * * * * /x/legacy.sh\n*/5 * * * * /x/new.sh\n' > "$T/entries"
assert_eq "merged_crontab replaces the block and drops old copies of its entries" "$(merged_crontab role "$T/entries")" \
  "$(printf 'MAILTO=""\n# BEGIN chakra-ops role\n15 * * * * /x/legacy.sh\n*/5 * * * * /x/new.sh\n# END chakra-ops role')"

FSTAB=$T/fstab; DRY_RUN=1
printf '${FOO} /mnt/x fuse.s3fs ro 0 0\n' > "$OPS_SRC/role/fstab.tmpl"
assert_contains "fstab: a missing entry is added" "$(install_fstab_line role/fstab.tmpl)" "/mnt/x (new)"
echo 'one /mnt/x fuse.s3fs ro 0 0' > "$FSTAB"
assert_contains "fstab: the same entry is left alone" "$(install_fstab_line role/fstab.tmpl)" "/mnt/x (unchanged)"
echo 'other /mnt/x nfs ro 0 0' > "$FSTAB"
assert_contains "fstab: a different entry for the mount point is not touched" "$(install_fstab_line role/fstab.tmpl)" "another entry exists"

finish
