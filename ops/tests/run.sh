#!/bin/bash
# Runs every ops test file with the current bash (4.3 or newer); exits non-zero if any assertion failed.
cd "$(dirname "$0")" || exit 1
rc=0
for t in ./*_test.sh; do
  echo "== ${t#./}"
  "$BASH" "$t" || rc=1
done
exit $rc
