#!/bin/bash
# shellcheck source=ops/tests/assert.sh
. "$(dirname "$0")/assert.sh" || exit 1
# shellcheck source=ops/lib/common.sh
. "$OPS/lib/common.sh"

out=$(CHAKRA_OPS_ENV=$T/missing.env; load_config 2>&1); rc=$?
assert_eq "load_config fails without the file" "$rc" 1
assert_eq "load_config names the file" "$out" "chakra-ops: config $T/missing.env not found; create it from ops/ops.env.example"

printf 'FOO=bar\nAWS_BIN=aws-test\nAWS_REGION=test-1\n' > "$T/ops.env"
CHAKRA_OPS_ENV=$T/ops.env
load_config
assert_eq "load_config reads values" "$FOO" bar

out=$(require_vars FOO MISSING_VALUE 2>&1); rc=$?
assert_eq "require_vars fails on a missing value" "$rc" 1
assert_eq "require_vars names the value and file" "$out" "chakra-ops: MISSING_VALUE is not set in $T/ops.env (see ops/ops.env.example)"
out=$(require_vars FOO 2>&1); rc=$?
assert_eq "require_vars passes when set" "$rc:$out" "0:"

require_aws
assert_eq "require_aws builds the CLI command" "${AWS[*]}" "aws-test --region test-1"

log_line "$T/x.log" hello world
assert_match "log_line writes a UTC timestamped line" "$(cat "$T/x.log")" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z hello world$'

finish
