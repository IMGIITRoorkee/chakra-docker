#!/bin/bash
# shellcheck disable=SC2016  # stub bodies and templates are literal on purpose
# shellcheck source=ops/tests/assert.sh
. "$(dirname "$0")/assert.sh" || exit 1
# shellcheck source=ops/lib/health.sh
. "$OPS/lib/health.sh"

stub curl 'case "$*" in *api/token*) echo tok ;; *instance-id*) echo i-0test ;; *) echo "${CURL_CODE:-200}" ;; esac'
stub aws 'echo "$*" > "$T/aws.args"; exit "${AWS_RC:-0}"'
AWS=(aws --region test-1)
LOG=$T/health.log
TS='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
DIM='Unit=Count,Dimensions=[{Name=InstanceId,Value=i-0test}]'

assert_eq "ok on success" "$(ok true)" 1
assert_eq "ok on failure" "$(ok false)" 0
assert_eq "http_ok on 200" "$(http_ok http://127.0.0.1/)" 1
assert_eq "http_ok on 500" "$(CURL_CODE=500 http_ok http://127.0.0.1/)" 0

declare -A check=([UpA]=1 [UpB]=1)
health_report "$LOG" "disk=10%" AgeHours=3
args=$(cat "$T/aws.args")
assert_match "pass: log line" "$(tail -1 "$LOG")" "$TS all_ok=1 disk=10% failed: none\$"
assert_contains "pass: namespace and region" "$args" "--region test-1 cloudwatch put-metric-data --namespace Chakra/Health --metric-data"
assert_contains "pass: each check" "$args" "MetricName=UpB,Value=1,$DIM"
assert_contains "pass: AllOk=1" "$args" "MetricName=AllOk,Value=1,$DIM"
assert_contains "pass: extra value" "$args" "MetricName=AgeHours,Value=3,$DIM"

check=([UpA]=1 [UpB]=0)
health_report "$LOG" "disk=10%"
args=$(cat "$T/aws.args")
assert_match "fail: log names the failed check" "$(tail -1 "$LOG")" "$TS all_ok=0 disk=10% failed: UpB\$"
assert_contains "fail: failed check published as 0" "$args" "MetricName=UpB,Value=0,$DIM"
assert_contains "fail: AllOk=0" "$args" "MetricName=AllOk,Value=0,$DIM"

check=([UpA]=1)
AWS_RC=1 health_report "$LOG" "disk=10%"
assert_match "publish failure is logged" "$(tail -1 "$LOG")" "$TS all_ok=1 disk=10% failed: PutMetricData\$"

finish
