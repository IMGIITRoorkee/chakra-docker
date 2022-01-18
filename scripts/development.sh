#!/bin/bash

# Let's start the docker container for DB

docker-compose up -d database

# Starting the flask server for chakra-core

source codebase/chakra-core/.env
cd codebase/chakra-core
flask run