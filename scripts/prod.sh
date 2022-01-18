#!/bin/bash

# This script runs the chakra core server

docker-compose up -d

cd codebase/chakra-core
source chakra-core-env/bin/activate
flask run
