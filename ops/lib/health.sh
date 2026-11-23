#!/bin/bash
# Health checks that publish to CloudWatch. The caller fills the associative array `check` (metric name -> 1 or 0).
# shellcheck source=ops/lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh" || exit 1

HEALTH_NAMESPACE=Chakra/Health                        # CloudWatch namespace the alarms watch
METADATA=http://169.254.169.254/latest                # EC2 instance metadata service (IMDSv2)

ok() { "$@" >/dev/null 2>&1 && echo 1 || echo 0; }
http_ok() { [ "$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$@")" = 200 ] && echo 1 || echo 0; }

ec2_instance_id() {
  curl -s -m 3 -X PUT "$METADATA/api/token" -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
    | xargs -I{} curl -s -m 3 -H 'X-aws-ec2-metadata-token: {}' "$METADATA/meta-data/instance-id"
}

# health_report <log> <details> [Metric=value...]: publishes every check, AllOk and the extra values, then logs one line.
health_report() {
  local log=$1 details=$2; shift 2
  local instance k v all=1 data="" failed=""
  instance=$(ec2_instance_id)
  # shellcheck disable=SC2154  # the caller declares check
  for k in "${!check[@]}"; do
    v=${check[$k]}; [ "$v" = 1 ] || { all=0; failed="$failed $k"; }
    data="$data $(metric "$k" "$v" "$instance")"
  done
  data="$data $(metric AllOk "$all" "$instance")"
  for k in "$@"; do data="$data $(metric "${k%%=*}" "${k#*=}" "$instance")"; done
  # shellcheck disable=SC2086
  "${AWS[@]}" cloudwatch put-metric-data --namespace "$HEALTH_NAMESPACE" --metric-data $data >/dev/null 2>&1 || failed="$failed PutMetricData"
  log_line "$log" "all_ok=$all $details failed:${failed:- none}"
}

metric() { echo "MetricName=$1,Value=$2,Unit=Count,Dimensions=[{Name=InstanceId,Value=$3}]"; }
