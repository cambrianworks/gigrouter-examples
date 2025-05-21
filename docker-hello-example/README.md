# GigRouter Docker Hello World

## Use Case

This is intended as a very simple example to show how to build (and run) an image with docker. In terms of k3s, producing a custom image on your local machine to run inside k3s can be accomplished by first creating a docker image.

## Application

The application simply prints "Hello world" as the intent is to get a basic understanding of docker, create an image, and launch a container based on the image.

## Quick start

If you'd just like to quickly launch everything, you can just run:

```
cd project
./0-prereqs.sh
```

Please pause at this point to ensure you have a working docker setup.

Then:

```
./1-build.sh
./2-run.sh
```

The "run" script without arguments launches the container and Python script (main application) in the foreground so you can directly see the output:

```
Running program in docker...
+ docker run --rm --name docker-hello docker-hello:latest
Hello, world!
```

Launch a new terminal before proceeding. After printing, the program sleeps for 10 minutes to simulate a longer running process. (You could also hit `Ctrl-c` to stop the program but then you'd have no running container to query below.)

Review the created image, running container, and the logs.

```
./3-review.sh
```

When you're done, you can perform some clean up with:

```
./4-del.sh
```

## Questions

Q: Why are we running docker if I want to run within k3s?

Here, docker is only used a means to an end. Later goals are to create images that can be used within k3s. Docker is a simple way to create images locally. Some other alternatives are cloud tooling that creates images given source files as well as `nerdctl` (contai`nerdctl`) which exposes a docker-like interface but lets you more directly interact with the `containerd` portion of k3s.

## Docker Hello World Files

For this example, the individual files can be downloaded and explored from the `project` directory here: [project](./project/)

### The files

- [project/](./project/)
  - [0-prereqs.sh](./project/0-prereqs.sh)
  - [1-build.sh](./project/1-build.sh)
  - [2-run.sh](./project/2-run.sh)
  - [3-review.sh](./project/3-review.sh)
  - [4-del.sh](./project/4-del.sh)
  - [docker-hello/](./project/docker-hello/)
    - [hello.py](./project/docker-hello/hello.py)
    - [Dockerfile](./project/docker-hello/Dockerfile)

### The parts

The numbered scripts are simply helper scripts that can be ran in the natural order to build, launch, and clean up the example. the `docker_hello` directory contains the `app.py` source code for our simple application and the `Dockerfile` indicates how to build the docker image for the example.

### Creating everything

This has been broken into a few numbered scripts that are inlined below. The comments should indicate what's happening.

As alluded to previously, the script 1 is simply trying to build a docker image. The progression from Docker images and containers to entire orchestration frameworks like k3s is certainly an interesting one but here it's just helpful to understand the basic concepts. You can think of images as a layered filesystem where many base images such as those for different flavors of Linux, databases, or images customized for Python are generally available as a starting point and the main magic is in knowing what exists and where the images are hosted. Once we've identified a base image, it's typical to see Dockerfiles that update or install any useful packages, copy any binaries, tools or configuration to the image, configure any ports, configure any mounted directories and, by convention, indicate some main process to launch. Building an image for an individual service isn't a requirement but it's a convention for modularity. One of the main benefits of images is that any dependent libraries or tools can be specifically customized within the image whereas running multiple services on a bare OS can be a nightmare if different services require different specific versions of dependencies. In Docker, if you think of the image as specifying some frozen state of the filesystem then containers are like lightweight virtual machines running on top of these filesystems. In k3s, a pod is a very lightweight container wrapper but could contain multiple containers. Under the hood, k3s uses `containerd` which is the same containerization system used by docker and thus why building docker images is useful.

The above description is primarily basic background since the steps here aren't directly tied to k3s but are more for bootstrapping an image locally so it can be available to your locally hosted k3s at some future point. You might have your own environment for building and hosting images so this just gives you a starting point to build an image that you could migrate to k3s without external dependencies. The main assumption is that you have Docker installed.

Before proceeding, first verify that you have the prerequisite environment set up:

`./0-prereqs.sh`

Here are the ordered scripts to run for setup and their contents.

`./1-build.sh`

<!-- inline: project/1-build.sh -->
```
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
```
<!-- endinline -->

After this step, if you were to run `docker images`, you should see one named `docker-hello:latest`.

**Important:** Below, we've added a `-d` option to demonstrate launching the container as a daemon.

`./2-run.sh -d`

<!-- inline: project/2-run.sh -->
```
#!/usr/bin/env bash

echo "Running program in docker..."

# Show commands being executed in script to what output of each
# command relates to.
set -x

# Use "-d" to run in background as daemon
docker run "$@" --rm --name docker-hello docker-hello:latest
```
<!-- endinline -->

Sample output:

```
Running program in docker...
+ docker run -d --rm --name docker-hello docker-hello:latest
49d398b2f1bc7b373b1565f16ae291e85bae355c3d9a3a28363b3f3122faac71
```

After this step, `docker ps` should show a container named `docker-hello` running.

Here, we run our program as a daemon with `-d` (container runs in background) and our program simply:
* Prints "Hello, world!" to stdout (which we only see in the logs in daemon mode)
* Sleeps for 10 minutes (so we can see our container is still "running" for some time after launch)
* Prints "Exiting after 10 minutes." to stdout prior to exiting

When running in the background, the last line of the output above is a unique container id assigned to the container. (When we launched in the foreground, hitting `Ctrl-c` would stop the process. When running in the background, you'd instead run `docker stop docker-hello` or use the container id `docker stop 49d398b2f1bc7b373b1565f16ae291e85bae355c3d9a3a28363b3f3122faac71`.)

Our docker command names our container `docker-hello` with the `--name` option. This has potential for conflicts if an old container with that name is already running. It's also problematic if we wanted to create multiple instances of a container as each would need a unique name. However, this offers the convenience of knowing the name of our docker container so we can identify it in a list as well as run commands that reference it.

If we didn't specify a container name, a unique name would be generated such as `ecstatic_banach`. Containers can also be referred to by their container id, where a shorthand appears under `CONTAINER ID` from `docker images` or the long id is printed to stdout when launching as a daemon.

For automatic cleanup, we created our container with `--rm` which means to automatically delete the container when it finishes. This both frees up our `docker-hello` name for a subsequent run as well as keeps stale processes from being listed in `docker ps -a`. The side-effect is that all traces of the container will vanish after removal so we'll never see our "Exiting after 10 minutes." output unless we're actively running `docker logs -f docker-hello` in another terminal prior to exit.

If we omit `--rm`, then:
* After our program exits, `docker ps -a` would still list the program as `STATUS=Exited`
* We could still query the container after exit - such as querying the logs post-exit with: `docker logs docker-hello`
* Our `docker-hello` name would still be in use and we'd have a name conflict if trying to relaunch our container with `--name docker-hello`
* For cleanup, we'd need to manually run: `docker rm docker-hello`

### Troubleshooting

If you noticed errors in running the previous steps, it would be good to review them now.

Some common errors could be:

* Docker setup or permissions
* Ran out of disk space or other key system resources (memory, etc.)

If there wasn't a happy path in running the above scripts then you'll likely need to do some investigation on your own to see what might be the problem.

### Reviewing what was created

`./3-review.sh`

Here, we'll use the next script to review a couple outputs after running the steps above.

<!-- inline: project/3-review.sh -->
```
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
```
<!-- endinline -->

We expect our output to show we've created an image where `docker images` should output something like:

```
REPOSITORY                                                         TAG                                IMAGE ID       CREATED              SIZE
docker-hello                                                       latest                             7f918edfa26d   About a minute ago   126MB
```

If we waited less than 10 minutes from launch to run this step, we should see our running container from `docker ps -a`:

```
CONTAINER ID   IMAGE                 COMMAND             CREATED              STATUS              PORTS     NAMES
e3fbdb65b0ea   docker-hello:latest   "python hello.py"   About a minute ago   Up About a minute             docker-hello
```

And, finally, we should see our hello line in stdout as viewed with `docker logs docker-hello`:

```
Hello, world!
```

**NOTE:** We set the following environment variable in our `Dockerfile` so that our stdout was flushed immediately else we might see nothing from stdout for some time (until the buffer is flushed or container finishes). From the `Dockerfile`:

```
ENV PYTHONUNBUFFERED=1
```

An equivalent trick would be to pass `-u` to the Python command line for the program. You would edit the `Dockerfile` and change:

```
CMD ["python", "hello.py"]
```

to:

```
CMD ["python", "-u", "hello.py"]
```

Finally, if you'd like to see the final stdout printout at the end of the program's 10 minute run, you could follow the output with:

```
docker logs -f docker-hello
```

You should see the first line output immediately but won't see the 2nd line until after the program completes. At this time, the we specified that the container should be automatically deleted so the logs command will also exit. Expected output (after completion of program):

```
Hello, world!
Exiting after 10 minutes.
```

### Initial cleanup

If we edited our Dockerfile and regenerated images multiple times, we can also get image cruft build up. It's wise to run the following regularly to clean up any stale unreferenced images:

```
docker image prune
```

You can also review the images created or downloaded by Docker with:

```
docker images
```

Example output:

```
REPOSITORY                                                         TAG                                IMAGE ID       CREATED                  SIZE
docker-hello                                                       latest                             ea83c37299d0   Less than a second ago   126MB
```

For more, information, see [../python-k3s-example-2/README-DOCKER-IMAGES](../python-k3s-example-2/README-DOCKER-IMAGES.md) which looks at images from the perspective of running example 2.

### Deleting example 2 resources

The script `4-del.sh` is a convenience script that will delete some artifacts of creating this example.

<!-- inline: project/4-del.sh -->
```
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
```
<!-- endinline -->

## Tips

### Docker image tags

The tags on docker images aren't necessarily static and something like `python:3.9-slim` could easily be out of date but newer images aren't pulled by default. A couple concerns are that (1) an image on your local machine might be old and missing important updates and (2) an image built on different machines from the same Dockerfile could be using different versions of the base image.

To download image updates, run: `docker pull IMAGE_NAME:TAG_NAME`.

Below is a short session that shows a couple images and that one was refreshed after a pull.

```
$ docker images | grep -E "python|alpine|REPOSITORY"
REPOSITORY                                                         TAG                                IMAGE ID       CREATED         SIZE
python                                                             3.9-slim                           9a041530811d   5 weeks ago     126MB
alpine                                                             latest                             91ef0af61f39   8 months ago    7.8MB


$ docker pull python:3.9-slim
3.9-slim: Pulling from library/python
Digest: sha256:bef8d69306a7905f55cd523f5604de1dde45bbf745ba896dbb89f6d15c727170
Status: Image is up to date for python:3.9-slim
docker.io/library/python:3.9-slim


$ docker pull alpine:latest
latest: Pulling from library/alpine
f18232174bc9: Pull complete 
Digest: sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
Status: Downloaded newer image for alpine:latest
docker.io/library/alpine:latest


$ docker images | grep -E "python|alpine|REPOSITORY"
REPOSITORY                                                         TAG                                IMAGE ID       CREATED         SIZE
python                                                             3.9-slim                           9a041530811d   5 weeks ago     126MB
alpine                                                             latest                             aded1e1a5b37   3 months ago    7.83MB
alpine                                                             <none>                             91ef0af61f39   8 months ago    7.8MB
```

Note that "IMAGE ID" `91ef0af61f39` is still present but now the "TAG" for `alpine:latest` has moved so that move action shows the old image has `<none>` as its tag. We could clean this up so we don't have that in our list:

```
$ docker image prune
WARNING! This will remove all dangling images.
Are you sure you want to continue? [y/N] y
Deleted Images:
untagged: alpine@sha256:beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d
deleted: sha256:91ef0af61f39ece4d6710e465df5ed6ca12112358344fd51ae6a3b886634148b

Total reclaimed space: 0B
```

The "0B" of reclaimed space likely indicates that the newer `alpine:latest` is still based on layers from the previous version(s).

## Summary

After working through this example, you should have a general understanding of how to create a docker image from a Dockerfile, run a container inside docker, see its output, list docker images, and see running docker containers.
