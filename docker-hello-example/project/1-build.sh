#!/usr/bin/env bash

# Build custom images using the Dockerfile for docker-hello.

# Assumes that docker is running locally
#  Test by listing running docker processes: docker ps
#
# We're just going to store images locally and not push to a repo
# so are using pretty bare names:
#  docker-hello:latest

# () runs each command in a subshell simply so we don't worry about
# stepping back out of directories we cd into.

# At some point, use of buildkit will be mandatory but below simply
# enforces that we don't require it to be installed though we expect
# to see deprecation warnings as of January, 2025.

echo "Building docker image..."

set -x

(cd docker-hello && DOCKER_BUILDKIT=0 docker build -t docker-hello:latest .)

set +x

echo ""
echo "If everything is working, you should see a line for docker-hello image."
docker images | grep -iE "docker-hello|REPOSITORY"
