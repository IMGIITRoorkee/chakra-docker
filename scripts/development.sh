#!/bin/bash

# Let's start the docker container for DB

trap ctrl_c INT

function ctrl_c() {
    echo "Stopping the dev server"
    docker-compose down
    exit
}

docker-compose up -d database

# Starting the flask server for chakra-core

source codebase/chakra-core/.env
cd codebase/chakra-core
source chakra-core-env/bin/activate
flask run --host=0.0.0.0

