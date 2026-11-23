#!/bin/bash
# Daily copy of root2's nginx config (as last pushed here) to the backup bucket; bucket versioning keeps 90 days of history.
set -euo pipefail
# shellcheck source=ops/lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh" || exit 1

load_config
require_vars BACKUP_BUCKET
require_aws

"${AWS[@]}" --only-show-errors s3 sync --delete /home/root2/nginx-incoming/ "$BACKUP_BUCKET/root2/nginx/"
date -u +%FT%TZ | "${AWS[@]}" s3 cp - "$BACKUP_BUCKET/status/last-success-root2-nginx.txt"
