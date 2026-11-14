#!/bin/bash

# This script clone the different cms repos into the codebase folder

set -euo pipefail

echo -e "Chakra -- Your one true CMS\n"

REPOS="chakra-core:master chakra-backend:master chakra-frontend:master chakra-library:staging"

for REPO in $REPOS; do
    NAME="${REPO%%:*}"
    BRANCH="${REPO##*:}"
    echo -e "\e[0;32mCloning ${NAME} (${BRANCH}) into ./codebase/${NAME}\e[0m"
    git clone --branch "$BRANCH" "https://github.com/IMGIITRoorkee/${NAME}" "./codebase/${NAME}" >/dev/null
done

echo "Everything cloned!"
