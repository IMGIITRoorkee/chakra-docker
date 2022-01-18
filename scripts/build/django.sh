#!/bin/bash

# Copy the prod-requirements.txt file from the codebase into the Django Docker folder
cp codebase/chakra-backend/requirements.txt      django/

# Enter the Django Docker folder
cd django/

# Build the container from the Django folder and tag it
TIMESTAMP=$(date +"%s")

docker build \
    --tag chakra-backend:${TIMESTAMP} \
    --tag chakra-backend:latest \
    .

# Remove the requirement files after they have served their purpose
rm requirements.txt