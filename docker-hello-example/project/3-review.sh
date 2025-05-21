#!/usr/bin/env bash

# Check running container in docker launched in last step
echo "Reviewing the docker container we created..."
echo "(This step is optional but would help highlight errors.)"

# Show commands being executed by script to easily see what output
# is associated with.
set -x

# Look at docker images to see docker-hello
docker images | grep -E "docker-hello|REPOSITORY"

# Check all running docker processes (where -a shows even if not "running")
docker ps -a

# Check the stdout of our container
docker logs docker-hello
