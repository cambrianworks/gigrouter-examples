#!/usr/bin/env bash

echo "Running program in docker..."

# Show commands being executed in script to what output of each
# command relates to.
set -x

# Use "-d" to run in background as daemon
docker run "$@" --rm --name docker-hello docker-hello:latest
