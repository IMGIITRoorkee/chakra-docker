#!/bin/bash
# Runs inside the chakra-core container. Reads .env literally (no shell expansion).
while IFS='=' read -r k v; do [ -n "$k" ] && export "$k=$v"; done < .env
exec python -m flask run --host=127.0.0.1 --port=5000
