#!/bin/bash

# Let's start the docker container for DB

docker network create -d bridge chakra-dev-network

trap ctrl_c INT

function ctrl_c() {
    echo "Stopping the dev server"
    docker stop 5432
    docker network rm chakra-dev-network
    exit
}

docker run \
    --tty \
    --rm \
    -d \
    --publish 5432:5432/tcp \
    --user postgres \
    --network chakra-dev-network \
    --volume database:/var/lib/postgresql/data \
    --name=5432 \
    --network-alias postgres5432 \
    --env-file postgres/database.env \
    chakra-postgres:latest

# Starting the flask server for chakra-core

source codebase/chakra-core/.env
cd codebase/chakra-core
source chakra-core-env/bin/activate
flask run

