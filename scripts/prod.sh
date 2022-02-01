#!/bin/bash

# This script runs the chakra core server

docker-compose up -d

trap handle_interrupt INT

function handle_interrupt() {
	cd ../../
	docker-compose down
	exit 0
}

cd codebase/chakra-core
source chakra-core-env/bin/activate
flask run --host=0.0.0.0

cd ../../
docker-compose down
