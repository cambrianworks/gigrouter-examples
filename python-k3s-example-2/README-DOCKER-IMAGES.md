# Docker Images

In the context of example 2, below gives some additional information on reviewing Docker images and clearing space.

Here are links to official Docker documentation:

[docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/) (aliases: `docker images`)

[docker image prune](https://docs.docker.com/reference/cli/docker/image/prune/)

[docker image pull](https://docs.docker.com/reference/cli/docker/image/pull/)

[docker image rm](https://docs.docker.com/reference/cli/docker/image/rm/) (aliases: `docker rmi`, `docker image remove`)

## Listing Images

Below assumes you might have edited the Dockerfiles in example 2 and rebuilt images a few times, each with minor changes.

You can see the stored images and their sizes with:

```
docker image ls
```

Or, equivalently:

```
docker images
```

Sample output:

```
$ docker images
REPOSITORY                   TAG               IMAGE ID       CREATED         SIZE
md5sum_service               latest            dd4b770cdeb8   1 days ago      161MB
<none>                       <none>            600ce5ad8852   1 days ago      161MB
<none>                       <none>            f25251289b5a   1 days ago      161MB
file_service                 latest            f89e2dd73da3   1 days ago      163MB
<none>                       <none>            6c643eaf33d7   1 days ago      163MB
<none>                       <none>            5ab5eefc0085   1 days ago      161MB
<none>                       <none>            7ca7567d7129   1 days ago      161MB
python                       3.9-slim          1ae0928a2c14   6 weeks ago     150MB
```

The `<none> <none>` pairs are a good indication that the images were created a few times and each time the latest image was tagged as `SERVICENAME:latest` the unreferenced images were left and had no tag. These are likely just eating up space and can be removed. HOWEVER, note that due to the `layering` of images mentioned previously, it's possible that some of your images can depend on others. In this case, you'll typically get a warning if you try to remove an image that another depends on. In other words, you should be safe from the worry of deleting something in use unless you use the `-f` or `--force` switch in the command below.

## Removing Docker Images

Let's remove the first two images from the output above using the `IMAGE ID`:

```
$ docker rmi 600ce5ad8852 f25251289b5a
Deleted: sha256:600ce5ad88529465ced53b5e6da015c37853b8e388665546a73a2fbfaa490b52
Deleted: sha256:1f1f2a4527ad1e2cfa40b2022f23475db646a9062feebaf334446ff8a24e5de0
Deleted: sha256:54c2df9a60373770a54737c1730793b2c01fa5d64beb75dd97195906a3e84bfb
Deleted: sha256:f25251289b5a4fb0156021b2e61226741464f32f943f8c499d7cd90e872d2dc1
Deleted: sha256:981ae6fff1ee82aba12a2b18cd6b550d418ab98040f6a82c1aeecd730c84a21f
Deleted: sha256:d616e13f473c966721e01ae81d7d07b047ba9c6f118bc2866cc4f33078c4d52d
Deleted: sha256:f0064ae841a13c5285c4fdc467139cc38c65f36cb0d4ca1b26504ef7a1a10790
Deleted: sha256:4a2171b94dc8fb489a51905840b28b1db27707f637f1129b5a2cd807f0497ccf
Deleted: sha256:e70f7c435aebe19fb64cd918068963f45220fbd9ffb21ac7aa01ac96a1ac13da
Deleted: sha256:58e50a89afdbb3c0a3a1a5764f14ad10ead2762b38410f3119169b1d01b10d76
```

What images are left?

```
$ docker images
REPOSITORY                   TAG               IMAGE ID       CREATED         SIZE
md5sum_service               latest            dd4b770cdeb8   1 days ago      161MB
file_service                 latest            f89e2dd73da3   1 days ago      163MB
<none>                       <none>            6c643eaf33d7   1 days ago      163MB
<none>                       <none>            5ab5eefc0085   1 days ago      161MB
<none>                       <none>            7ca7567d7129   1 days ago      161MB
python                       3.9-slim          1ae0928a2c14   6 weeks ago     150MB
```

Is there an easier way to remove these unreferenced images? Yes, we can with:

```
docker image prune
```

Sample output:

```
$ docker image prune
WARNING! This will remove all dangling images.
Are you sure you want to continue? [y/N] y
Deleted Images:
deleted: sha256:91c811b8d0a5dc1a91c159ac61bcc2784974d11af0084fd1b1e1516c0221c004
deleted: sha256:99e92c53cbd734fbda041c2e4bfc87bd3e3a5acaa464fed9c748bde65ddb4e1e
deleted: sha256:fde6ce133a961f9d17c32629a3ecf7e2dfcfc89debb7859abb9c8cf82d15a0c1
deleted: sha256:3683c40ed7945b40773bc6b53d52119dd011c00b4b94108bc4d27940fdb73cd4
deleted: sha256:78eca7f19cf61608ef0f8f0fae4151913d2b9802a5e1b7536ebb702174deef89
deleted: sha256:a293427522ce8b3d7457317e427c34e13ae61c79652840a0d659d203e1e52b83
deleted: sha256:5ab5eefc00853a8a116346df4ee1d679a528f4a96ee9e0a59d1adf6f6046e920

...

deleted: sha256:feb66849949960183aa3f287d2207e324d1bc330ee86b37079eed93bc31c9a1f
deleted: sha256:c5b3b0f6a2d499f2ad708042faddf104ba8280ec79f418d1865ec8094aff92a3
deleted: sha256:53a66b0196348982786dddae122d195f41de1ce82bc0ed8e4dc102f4920336d9
deleted: sha256:1365cad169189d8d2fd12d4929e4ece06dcb40bff6ca285a5460974b9a92dd72
deleted: sha256:cbb6fc416c5a6e4d8c8c118768fe5f82cc7ac5dc8ba0762697531c4d8c47c870
deleted: sha256:4b551522f37194e89c5f3afa1874475399d8d962c4d9c30a185cb60fabdac40e

Total reclaimed space: 99.13MB
```

Why is this only 99.13MB when we saw 3 unreferenced images at 160+ MB each? Again, this relates to **layering**. What we've created is on top of existing base images that are still present and our changes are relatively small. It all depends on what we do in our image creation steps.

## Removing containerd Images

Similarly, you should regularly prune `containerd` images:

```
sudo k3s ctr images prune --all
```

## Reviewing Filesystem Usage for Docker

Let's look at the images again:

```
$ docker images
REPOSITORY                   TAG               IMAGE ID       CREATED         SIZE
md5sum_service               latest            dd4b770cdeb8   1 days ago      161MB
file_service                 latest            f89e2dd73da3   1 days ago      163MB
python                       3.9-slim          1ae0928a2c14   6 weeks ago     150MB
```

Where does Docker store these images?

The default for image storage is `/var/lib/docker` unless `data-root` has been specified in Docker's main config which would appear as follows:

```
$ grep data-root /etc/docker/daemon.json
"data-root": "/custom/path/for/docker-data"
```

Inspecting that directory:

```
$ sudo bash -c 'du -hs /var/lib/docker/*'
104K	/var/lib/docker/buildkit
236K	/var/lib/docker/containers
4.0K	/var/lib/docker/engine-id
8.0M	/var/lib/docker/image
52K	/var/lib/docker/network
13G	/var/lib/docker/overlay2
16K	/var/lib/docker/plugins
4.0K	/var/lib/docker/runtimes
4.0K	/var/lib/docker/swarm
4.0K	/var/lib/docker/tmp
28K	/var/lib/docker/volumes
```

`13G` in `/var/lib/docker/overlay2` is a good indication that images are being stored there.

You can find how much disk space is free versus used with `df` (disk free):

```
$ df -h /var/lib/docker
Filesystem      Size  Used Avail Use% Mounted on
/dev/mmcblk0p1   54G   36G   16G  70% /
```

In the case above, it looks like `/var/lib/docker` is a good amount of the disk used and this is all in the main root file system `/`.

For this machine, it would be wise to either mount `/var` in its own larger partition, keep careful watch on Docker filesystem usage, or create/configure `/etc/docker/daemon.json`.

## Reviewing Filesystem Usage for containerd

For k3s, images are also stored by `containerd`. Let's check its usage, too.

We should be able to find the main k3s data dir in this config file:

```
$ cat /etc/rancher/k3s/config.yaml
data-dir: /mnt/system-data
write-kubeconfig-mode: "0644"
```

Assuming directory is as above, check disk usage:

```
$ sudo bash -c 'du -hs /mnt/system-data/*'
1.3G	/mnt/system-data/agent
388M	/mnt/system-data/data
23M	/mnt/system-data/server
4.0K	/mnt/system-data/storage
```

Drilling down into `agent` directory:

```
$ sudo bash -c 'du -hs /mnt/system-data/agent/containerd'
1.3G	/mnt/system-data/agent/containerd
```

If the above path doesn't patch your configuration, you should be able to extract the `data-dir` with:

```
export K3S_DATA_DIR=`cat /etc/rancher/k3s/config.yaml | grep ^data-dir: | sed 's/.*: //'`
```

Check it:

```
$ echo $K3S_DATA_DIR
/mnt/system-data
```

Then, you should be able to reference as `$K3S_DATA_DIR`. For example:

```
$ sudo du -hs $K3S_DATA_DIR/agent/containerd
1.3G	/mnt/system-data/agent/containerd
```

## Refreshing Docker images

When reviewing Docker images, we had one for Python that was pulled from a public repository.

```
$ docker images
REPOSITORY                   TAG               IMAGE ID       CREATED         SIZE
python                       3.9-slim          1ae0928a2c14   6 weeks ago     150MB
```

The `TAG` `3.9-slim` isn't necessarily fixed to a particular image and could have been updated in the background. It could have bug fixes or other updates. By default, when our Dockerfile references `python:3.9-slim`, the latest image isn't pulled if an existing image is present. Note that we can see above that this image is from `6 weeks ago`.

We could use the following option when we `docker build` one of our custom images (to `pull` the latest base image):

```
      --pull                    Always attempt to pull a newer version of
                                the image
```

We can also pull the latest image with:

```
docker image pull python:3.9-slim
```

Sample output:

```
$ docker image pull python:3.9-slim
 
3.9-slim: Pulling from library/python
7ce705000c39: Pull complete 
d02d1a1ced20: Pull complete 
599c1ad860e3: Pull complete 
c3c1c8618302: Pull complete 
Digest: sha256:bb8009c87ab69e751a1dd2c6c7f8abaae3d9fce8e072802d4a23c95594d16d84
Status: Downloaded newer image for python:3.9-slim
docker.io/library/python:3.9-slim
```

We can see the `IMAGE ID` changed.

```
$ docker images
REPOSITORY                   TAG               IMAGE ID       CREATED         SIZE
python                       3.9-slim          4681481d939a   4 weeks ago     151MB
```
