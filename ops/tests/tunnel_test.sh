#!/bin/bash
# shellcheck disable=SC2016  # stub bodies and templates are literal on purpose
# shellcheck source=ops/tests/assert.sh
. "$(dirname "$0")/assert.sh" || exit 1
# shellcheck source=ops/lib/reverse-tunnel.sh
. "$OPS/lib/reverse-tunnel.sh"

stub ssh 'echo "$*" >> "$T/ssh.args"; exit 3'
# The loop never ends on its own: the first pause stops it.
stub sleep 'echo "$1" > "$T/slept"; kill -TERM "$PPID"'

(trap "exit 0" TERM; reverse_tunnel "$T/lock" "$T/tunnel.log" 127.0.0.1:2222:127.0.0.1:22 user@host -i key)
assert_eq "ssh gets the forward, destination and extra options" "$(cat "$T/ssh.args")" \
  "-N -i key -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R 127.0.0.1:2222:127.0.0.1:22 user@host"
assert_match "an exit is logged with ssh's status" "$(cat "$T/tunnel.log")" '^[0-9T:-]+Z tunnel exited with 3, reconnecting$'
assert_eq "it pauses before reconnecting" "$(cat "$T/slept")" 10

rm -f "$T/ssh.args"
exec 8>"$T/lock"; flock -n 8
(reverse_tunnel "$T/lock" "$T/tunnel.log" 127.0.0.1:2222:127.0.0.1:22 user@host); rc=$?
assert_eq "a second instance exits cleanly while the lock is held" "$rc:$([ -e "$T/ssh.args" ] && echo ran || echo idle)" "0:idle"

finish
