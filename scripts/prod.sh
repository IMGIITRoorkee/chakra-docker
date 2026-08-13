#!/bin/bash

# This script runs the chakra core server

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CURRENT_UID=$(id -u):$(id -g) docker-compose up -d

trap handle_interrupt INT

function handle_interrupt() {
	cd "$ROOT"
	docker-compose down
	exit 0
}

cd "$ROOT/codebase/chakra-core"
source chakra-core-env/bin/activate
flask run --host=0.0.0.0

cd "$ROOT"
docker-compose down
