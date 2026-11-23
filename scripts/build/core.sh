#!/bin/bash

# Copy the requirements.txt file from the codebase into the core Docker folder
cp codebase/chakra-core/requirements.txt core/

# Enter the core Docker folder
cd core/

# Build the container from the core folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag chakra-core:${TIMESTAMP} \
    --tag chakra-core:latest \
    .

# Remove the requirement file after it has served its purpose
rm requirements.txt
