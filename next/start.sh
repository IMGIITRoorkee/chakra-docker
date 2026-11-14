#!/bin/bash
# Runs in the frontend container: rebuilds only when a source file or PROXY (baked into the build) changed since the last build.
set -e

stamp=.next/BUILT_FOR_PROXY

needs_build() {
  [ -f .next/BUILD_ID ] || return 0
  [ "$(cat "$stamp" 2>/dev/null)" = "$PROXY" ] || return 0
  [ -n "$(find . \( -path ./node_modules -o -path ./.next -o -path ./.git \) -prune -o -type f -newer .next/BUILD_ID -print -quit)" ]
}

if needs_build; then
  yarn build
  echo "$PROXY" > "$stamp"
else
  echo "Sources unchanged since the last build, skipping yarn build"
fi

pm2 start yarn --name nextjs --interpreter bash -- start
pm2 monit
