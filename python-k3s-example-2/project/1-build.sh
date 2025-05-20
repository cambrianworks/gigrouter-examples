#!/usr/bin/env bash

# Build custom images using the Dockerfile for each of file_service
# and md5sum_service.

# Assumes that docker is running locally
#  Test by listing running docker processes: docker ps
#
# We're just going to store images locally and not push to a repo
# so are using pretty bare names:
#  file_service:latest
#  md5sum_service:latest

# () runs each command in a subshell simply so we don't worry about
# stepping back out of directories we cd into.

# At some point, use of buildkit will be mandatory but below simply
# enforces that we don't require it to be installed though we expect
# to see deprecation warnings as of January, 2025.

echo "Building docker images..."

(cd file_service && DOCKER_BUILDKIT=0 docker build -t file_service:latest .)
(cd md5sum_service && DOCKER_BUILDKIT=0 docker build -t md5sum_service:latest .)

echo ""
echo "If everything is working, you should see lines for each of the following"
echo "service images: md5sum_service file_service"
docker images | grep -iE "[file|md5sum]_service|REPOSITORY"
