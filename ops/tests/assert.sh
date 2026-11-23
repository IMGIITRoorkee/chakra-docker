#!/bin/bash
# Assertions and command stubs for the ops tests. Each test file sources this and ends with finish.

# shellcheck disable=SC2034  # used by the test files
OPS=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
STUBS=$T/bin
FAILS=0
mkdir -p "$STUBS"
PATH=$STUBS:$PATH
export T
trap 'rm -rf "$T"' EXIT

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1: $2"; FAILS=$((FAILS + 1)); }
assert_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$3', got '$2'"; fi; }
assert_contains() { if [[ $2 == *"$3"* ]]; then pass "$1"; else fail "$1" "'$3' not in '$2'"; fi; }
assert_not_contains() { if [[ $2 != *"$3"* ]]; then pass "$1"; else fail "$1" "'$3' found in '$2'"; fi; }
assert_match() { if [[ $2 =~ $3 ]]; then pass "$1"; else fail "$1" "'$2' does not match /$3/"; fi; }

stub() {  # stub <command> <bash body>: shadows the command on PATH for this test file
  printf '#!/bin/bash\n%s\n' "$2" > "$STUBS/$1"
  chmod +x "$STUBS/$1"
}

finish() { echo "$FAILS failed"; [ "$FAILS" = 0 ]; }
