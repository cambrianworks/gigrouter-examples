#!/usr/bin/env bash

echo "This is a clean-up step to stop docker container and clean up some resources"

set -x

# Note that this will return an error if the container isn't running
docker stop docker-hello

# This is listed as a formality as we launch the container with "--rm"
# which means to auto-delete when the container finishes.
# IF the container IS running and we DIDN'T run stop above, we'd need
# to use "-f" for "docker rm" to succeed with a running container:
# docker rm -f docker-hello
docker rm docker-hello

# Remove image
docker rmi docker-hello:latest

# Prune any orphaned images
docker image prune
