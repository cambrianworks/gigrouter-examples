# GigRouter K3s Python Example 2

## Use Case

The intent of this example is to demonstrate file uploads, use of a database, use of persistent storage, configuring an ingress and querying a service in another k3s pod.

One assumption is that the actual code is relatively self-explanatory. The focus of this example is not on the code itself but understanding how to support running the code under k3s as well as what other k3s tooling is useful.

## Application

This Python example supports file transfer examples in Flask with POST, logs metadata into an sqlite database, creates a second md5sum service to show interaction between services across pods, configures a traefik ingress for forwarding http traffic, and stores uploaded data in a persistent volume in k3s. Docker images are transferred from local storage in Docker to files that can be imported into `containerd` which is used by k3s for managing images.

The assumption is that file transfer is a generally useful feature and that the corresponding ingress, database, and persistent storage are all important to understand for supporting similar use cases.

## Quick start

If you'd just like to quickly launch everything then later explore the running services, you can just run:

```
cd project
./0-prereqs.sh
```

Please pause at this point to ensure you have a working k3s and docker setup.

Then:

```
./1-build.sh
./2-containerd-import.sh
./3-apply.sh
```

Optionally, review the k3s resources:

```
./4-review.sh
```

**Test the service:**

See [Testing service](#testing-service) section below to try uploading some files and computing md5 sums.

When you're done, you can clean up the k3s resources and some other temp files with:

```
./5-del.sh
```

## Example 2 - Walkthrough

For this example, the individual files can be downloaded and explored from the `project` directory here: [project](./project/)

### The files

- [project/](./project/)
  - [0-prereqs.sh](./project/0-prereqs.sh)
  - [1-build.sh](./project/1-build.sh)
  - [2-containerd-import.sh](./project/2-containerd-import.sh)
  - [3-apply.sh](./project/3-apply.sh)
  - [4-review.sh](./project/4-review.sh)
  - [5-del.sh](./project/5-del.sh)
  - [file_service/](./project/file_service/)
    - [app.py](./project/file_service/app.py)
    - [database.py](./project/file_service/database.py)
    - [requirements.txt](./project/file_service/requirements.txt)
    - [Dockerfile](./project/file_service/Dockerfile)
  - [md5sum_service/](./project/md5sum_service/)
    - [md5sum_service.py](./project/md5sum_service/md5sum_service.py)
    - [requirements.txt](./project/md5sum_service/requirements.txt)
    - [Dockerfile](./project/md5sum_service/Dockerfile)
  - [k3s/](./project/k3s/)
    - [pv.yaml](./project/k3s/pv.yaml)
    - [pvc.yaml](./project/k3s/pvc.yaml)
    - [middleware.yaml](./project/k3s/middleware.yaml)
    - [traefik-ingress.yaml](./project/k3s/traefik-ingress.yaml)
    - [deployment-file-service.yaml](./project/k3s/deployment-file-service.yaml)
    - [service-file-service.yaml](./project/k3s/service-file-service.yaml)
    - [deployment-md5sum.yaml](./project/k3s/deployment-md5sum.yaml)
    - [service-md5sum.yaml](./project/k3s/service-md5sum.yaml)

### The parts

At a high-level, each directory `file_service` and `md5sum_service` contain Python code for a Flask service as well as a Dockerfile for taking a base image supporting Python and layering in the custom code.

Then, the `k3s` directory contains `yaml` files that can be applied to launch the services within k3s. Note that some of these files must be applied in a specific order and with certain prerequisite assumptions.

The files in the `k3s` directory are, in a nutshell:

* `pv.yaml` defines a persistent volume to be mounted on the host directory so database and file uploads will persist even if transient pods are deleted
* `pvc.yaml` defines a claim on the persistent volume which will attach to the persistent volume
* `middleware.yaml` configures `strip-file-prefix` middleware to remove `/file` prefix from http traffic which relates to the file service and attaching it to `/file` in the ingress
* `traefik-ingress.yaml` configures the built-in `traefik` service for routing http:// and https:// into each of our two services. If the URL path begins with `/md5` then traffic is routed to the md5sum service and traffic that begins with `/file` is routed to the file service with the middleware stripping the `/file` prefix. The file service itself supports `/upload`, `/download`, and `/files`. The service could still run without stripping the `/file` prefix but the Flask service would then have to be updated to support `/file/upload`, `/file/download`, and `/file/files`.
* `deployment-file-service.yaml` sets up file service as a deployment similar to how example 1 set up the http:// `add` service. The key differences are:
  * The `add` deployment used a vanilla Python `python:3.11-slim` image
  * The `file` deployment uses the custom image we built with our `Dockerfile` and the pull policy is set to `Never` to reinforce that we manually copy our image to `containerd`
  * The `file` deployment uses a persistent volume claim to mount our persistent volume at `/data`
  * The `file` deployment listens at less standard port `5000` instead of `8080` but this is simply an arbitrary destination that the service and ingress will be forwarding to
* `service-file-service.yaml` sets up the service portion of file service
  * Whereas example 1 demonstrated `LoadBalancer`, example 2 uses the k3s default `ClusterIP` which, if used by itself, would mean the service would only be available **within** the k3s cluster nodes and pods (not to external computers) either as `file-service:80` from pods or `ASSIGNED_CLUSTER_IP:80` on machines within the cluster hosting the k3s nodes. That is, you couldn't use this standalone from external computers without a port forward or configuring an ingress such as `traefik`. But, if you want to build k3s behind-the-scenes services used only by your other k3s pods, this could be adequate.
* `deployment-md5sum.yaml` sets up the md5sum service as a deployment using port `5001` as our arbitrary internal port that the ingress will forward to and references the custom image built from the `md5sum_service` directory
* `service-md5sum.yaml` sets up the service portion of md5sum service which is nearly identical to that of the file service but using the md5sum name and appropriate `targetPort`

### Creating everything

This has been broken into a few numbered scripts that are inlined below. The comments should indicate what's happening.

Scripts 1 and 2 are simply trying to create and make images available to k3s after using docker tooling to create the initial image. If you're unfamiliar with docker and docker images, you could take a step back to review [docker-hello-example](../docker-hello-example/README.md).

Before proceeding, first verify that you have the prerequisite environment set up:

`./0-prereqs.sh`

Here are the ordered scripts to run for setup and their contents.

`./1-build.sh`

<!-- inline: project/1-build.sh -->
```
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
```
<!-- endinline -->

`./2-containerd-import.sh`

<!-- inline: project/2-containerd-import.sh -->
```
#!/usr/bin/env bash

echo "Saving docker images then importing into k3s containerd..."

docker save file_service:latest -o file_service.tar
docker save md5sum_service:latest -o md5sum_service.tar

# For file_service
sudo k3s ctr images import file_service.tar

# For md5sum_service
sudo k3s ctr images import md5sum_service.tar
```
<!-- endinline -->

`./3-apply.sh`

<!-- inline: project/3-apply.sh -->
```
#!/usr/bin/env bash

echo "Applying all k3s manifest yaml files..."

# Show commands being executed in script to what output of each
# command relates to.
set -x

# Set up persistent volumes; we've set flags to auto-create directory if needed

kubectl apply -f k3s/pv.yaml
kubectl apply -f k3s/pvc.yaml

kubectl apply -f k3s/deployment-file-service.yaml
kubectl apply -f k3s/service-file-service.yaml

kubectl apply -f k3s/deployment-md5sum.yaml
kubectl apply -f k3s/service-md5sum.yaml

kubectl apply -f k3s/middleware.yaml
kubectl apply -f k3s/traefik-ingress.yaml
```
<!-- endinline -->

`./4-review.sh`

<!-- inline: project/4-review.sh -->
```
#!/usr/bin/env bash

# This is just to inspect what we created in k3s.
echo "Reviewing the k3s resources we created..."
echo "(This step is optional but would help highlight errors.)"

# Show commands being executed by script to easily see what output
# is associated with.
set -x

# Check persistent volumes
kubectl get pv file-upload-pv
kubectl describe pv file-upload-pv
kubectl get pvc file-upload-pvc
kubectl describe pvc file-upload-pvc

# Get some info on the ingress
kubectl get middleware/strip-file-prefix
kubectl get ingress/multi-service-ingress
kubectl describe ingress/multi-service-ingress

# Check services and deployments
# For more info use "describe" instead of "get" or use option "-o yaml"
kubectl get deploy/file-service
kubectl get svc/file-service
kubectl get deploy/md5sum-service
kubectl get svc/md5sum-service
```
<!-- endinline -->

For now, just quickly scan the commands you ran in the scripts above and look for any glaring errors. The comments in the scripts above should suffice to show what's getting set up. If you see problems, you can jump to the [Troubleshooting](#troubleshooting) section.

For some more drilldown into some nuances of the k3s setup above, see [Additional K3s Notes](#example-2-additional-k3s-notes).

If everything looks good at this point, just continue to the section below to try uploading some files and computing md5 sums.

### Testing service

Our example services support file transfer and computing md5 sums. Below, we make heavy use of the `curl` command though you could use other standard tools and libraries.

Here, we can get the md5sum of the string "test data".

Recall that the ingress is directing `/md5` to our md5 sum service and `/file` to our file service.

```
$ curl -X POST --data-binary "test data" http://localhost/md5
{"md5sum":"eb733a00c0c9d336e65691a37ab54293"}
```

Rather than put the file contents on the command line, we can have `curl` read from a file with `@filename`. The `-n` argument to `echo` omits outputting a newline after the input string in order to match the same input we used on the command line to see we get the same md5 sum.

```
echo -n "test data" > testfile.txt
$ curl -X POST --data-binary "@testfile.txt" http://localhost/md5
{"md5sum":"eb733a00c0c9d336e65691a37ab54293"}
```

Next, we use a similar command to upload a file to our service.

```
$ curl -X POST -F "file=@testfile.txt" http://localhost/file/upload
{"filename":"testfile.txt","md5sum":"eb733a00c0c9d336e65691a37ab54293","path":"/data/uploads/testfile.txt","size":9}
```

The json response gives some info on the uploaded file that was stored. We can use the following to list what files have been uploaded and are currently stored:

```
$ curl http://localhost/file/files
[{"filename":"testfile.txt","md5sum":"eb733a00c0c9d336e65691a37ab54293","path":"/data/uploads/testfile.txt","size":9}]
```

Using the value for `filename`, let's see if we can download the file that the server is now hosting:

```
$ mkdir testdir && cd testdir
$ curl -O http://localhost/file/download/testfile.txt
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100     9  100     9    0     0   1500      0 --:--:-- --:--:-- --:--:--  1500
```

Can we use https too? We should have https by default but many browsers and tools guard against self-signed certificates. The certificate provides encryption support but certificates are also used to help ensure public web servers are legitimate.

```
$ curl https://localhost/file/files
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

The default self-signed security certificate is giving us trouble. Add the `--insecure` option.

```
$ curl --insecure https://localhost/file/files
[{"filename":"testfile.txt","md5sum":"eb733a00c0c9d336e65691a37ab54293","path":"/data/uploads/testfile.txt","size":9}]
```

Check the pv directory on host:

```
$ sudo ls -la /usr/local/gigrouter/k3s/pv/file-server
total 24
drwxr-xr-x 3 root root  4096 Jan 22 01:05 .
drwxr-xr-x 3 root root  4096 Jan 22 01:05 ..
-rw-r--r-- 1 root root 12288 Jan 22 01:05 metadata.db
drwxr-xr-x 2 root root  4096 Jan 22 01:05 uploads
```

Above shows that `metadata.db` holds the contents of our database and that all of our files are stored in the `uploads` directory.

### Deleting example 2 resources

Please continue exploring or altering the sample services as much as you see fit. The section below will help you clean up your k3s resources once you are done with this example.

Also note the [follow-on](#follow-on) section that you might want to review try prior to deleting resources.

#### Deletion Convenience Script

The script `5-del.sh` is a convenience script that will delete some file artifacts, image artifacts, and the k3s resources for example 2.

<!-- inline: project/5-del.sh -->
```
#!/usr/bin/env bash

echo "This is a clean-up step to delete transient data and k3s resources..."

rm -f file_service.tar md5sum_service.tar
docker rmi md5sum_service:latest file_service:latest

kubectl delete ingress/multi-service-ingress middleware/strip-file-prefix svc/file-service deployments.apps/file-service svc/md5sum-service deploy/md5sum-service pvc/file-upload-pvc pv/file-upload-pv

HOST_PATH="/usr/local/gigrouter/k3s/pv/file-server"
echo ""
echo ""
echo "Checking host for files remaining from persistent volume"
echo "at: ${HOST_PATH}"
ls -laR "${HOST_PATH}"
echo ""
echo "You can manually remove any files at '${HOST_PATH}'"
echo "to remove files saved by service."
```
<!-- endinline -->

Sample output:

```
ingress.networking.k8s.io "multi-service-ingress" deleted
middleware.traefik.containo.us "strip-file-prefix" deleted
service "file-service" deleted
deployment.apps "file-service" deleted
service "md5sum-service" deleted
deployment.apps "md5sum-service" deleted
persistentvolumeclaim "file-upload-pvc" deleted
persistentvolume "file-upload-pv" deleted


Checking host for files remaining from persistent volume
at: /usr/local/gigrouter/k3s/pv/file-server
/usr/local/gigrouter/k3s/pv/file-server:
total 24
drwxr-xr-x 3 root root  4096 Jan 23 19:58 .
drwxr-xr-x 3 root root  4096 Jan 22 01:05 ..
-rw-r--r-- 1 root root 12288 Jan 23 19:58 metadata.db
drwxr-xr-x 2 root root  4096 Jan 23 19:58 uploads

/usr/local/gigrouter/k3s/pv/file-server/uploads:
total 16
drwxr-xr-x 2 root root 4096 Jan 23 19:58 .
drwxr-xr-x 3 root root 4096 Jan 23 19:58 ..
-rw-r--r-- 1 root root  195 Jan 23 19:58 pvc.yaml
-rw-r--r-- 1 root root  384 Jan 23 19:58 pv.yaml
```

Note that the files from our persistent volume are still present on the host.

#### Additional Cleanup and Notes

Check that your filesystem has adequate size for your temporary Docker images which is `/var/lib/docker` by default.

You can also review the images created or downloaded by Docker with:

```
docker images
```

Example output:

```
$ docker images
REPOSITORY                   TAG               IMAGE ID       CREATED         SIZE
md5sum_service               latest            dd4b770cdeb8   1 days ago      161MB
<none>                       <none>            600ce5ad8852   1 days ago      161MB
file_service                 latest            f89e2dd73da3   1 days ago      163MB
python                       3.9-slim          1ae0928a2c14   6 weeks ago     150MB
```

If we edited our Dockerfile and regenerated images multiple times, we can also get image cruft build up. It's wise to run the following regularly to clean up any stale unreferenced images:

```
docker image prune
```

Similarly, you should regularly prune `containerd` images:

```
sudo k3s ctr images prune --all
```

For more information, see [README-DOCKER-IMAGES](./README-DOCKER-IMAGES.md).

## Questions

Q: What if I want something besides an sqlite database?

Sqlite is used as one of the simplest types of flat file databases. Many frameworks are plug-and-play with respect to databases and easily let you swap in a more formal database such as postgresql. A ready-to-use postgresql image or other database image should be available for k3s. Swapping to a different database should be relatively straightforward.

Q: Isn't the use of local files to move between Docker and `containerd` a bit of a hack?

It would be more standard practice to push and pull your images from a server. However, this example doesn't want to rely excessively on external networking or make assumptions about a custom provider. "Official" images outside of the examples are hosted on Cloudsmith or pulled directly from public image repos such as for the `otel` image. Here, the goal is just to create an image using Docker tooling and then make that image accessible within k3s.

## Troubleshooting

If you noticed errors setting up the services, some tips are below.

Some common errors could be:

* Docker wasn't available or your user had insufficient permissions
* Inadequate permissions for creating filesystems or running certain commands
* Ran out of disk space or other key system resources (memory, etc.)
* k3s wasn't available or was missing key services (coredns, middleware support)
* Conflicting services such as a port conflict
* Issue mounting or creating a persistent volume

If there wasn't a happy path in running the above scripts then you'll likely need to do some investigation on your own to see what might be the problem.

The [README-K3S-OVERVIEW](../README-K3S-OVERVIEW.md) contains some useful information to help with k3s understanding and troubleshooting as well as provides links to other documents.

## Follow-on

Reading and working through the following supplements is strongly recomended to get a good understanding of persistent volumes, k3s ingress support and the exercises explore more of k3s and working with this example.

### README-PV.md

See [README-PV](./README-PV.md) for more information on persistent volumes and troubleshooting, especially if you don't see the expected sqlite database and uploads directory.

### README-INGRESS.md

See [README-INGRESS](./README-INGRESS.md) for a more detailed look into the ingress setup for example 2.

### README-EXERCISES.md

See [README-EXERCISES](./README-EXERCISES.md) to show some customizations of this example, interacting with the pods (copying files and getting a bash login to a pod) and an example of scaling pod count.

## Summary

After working through this example and the various follow-ons, you should have a general understanding of how to support an http endpoint for file uploads with Flask in Python, how to use and backup an sqlite database, how to make use of persistent volumes for storage of the database and uploaded files, how to configure an ingress for http endpoints and how to make a query from one k3s pod to a k3s service running in another pod.

## Example 2 Additional K3s Notes

There's a lot happening behind the scenes in the k3s setup and some callouts are worth mentioning.

The kube-to-kube calls from the file service to the md5sum service simply reference `md5sum-service` as if it's a hostname and it's worth understanding what's going on here and how this name lookup works.

In the case of PVCs, the example script sets up a fully working environment and so some nuances of lazy instantiation are missed. Namely, if you start experimenting with creating your own PVCs and reviewing the created resources, you might be surprised to see that the PVC waits (by default) for a k3s resource to use it before completing volume creation. If you're looking for creation of an empty mounted PV, you might otherwise be surprised and think something failed.

### kube-dns

K3s uses CoreDNS as its implemention of kube-dns. The pods within k3s can reference other pods or services by name depending on configuration. A pod would be resolvable if configured with a `hostname` and `subdomain`. However, below, the service definition is being used and both pods are in the same namespace so the simple service name below is adequate. Here's how `app.py` in the `file_service` directory references the md5 sum service:

```
response = requests.post('http://md5sum-service/md5', data=file_bytes, headers=headers)
```

Note that http:// signifies that non-secure port 80 will be used for this communication. Let's double-check below how the md5 sum service is configured to see its name and the port in use:

```
$ kubectl get svc -o wide -n default
NAME             TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)          AGE    SELECTOR
md5sum-service   ClusterIP      10.43.157.176   <none>          80/TCP           19h    app=md5sum-service
```

Pods generally contain a unix-standard `/etc/resolv.conf` file that indicates a lookup strategy when shorthand DNS names are used. A typical configuration would contain:

```
search default.svc.cluster.local svc.cluster.local cluster.local
```

Because of this search, the name `md5sum-service` was an adequate shorthand to resolve the IP for the service.

A pod in a different namespace would need to use a more fully qualified version of `md5sum-service` for name resolution. The "fully qualified" version of the name is: `md5sum-service.default.svc.cluster.local` where you should note that `default` is the namespace in use and `svc` indicates the record is for a service. If a pod was configured with a DNS entry, the fully qualified name would end with `.pod.cluster.local`.

A couple other notes for clarification:

1. If we had connected directly to the pod instead of the service then we would have had to use port 5001 instead of 80 as indicated in `deployment-md5sum.yaml`.
2. Since we are connecting directly to the service (internally) the ingress is not needed for this pod-to-pod communication which means (a) we only use http/80 and not https/443, (b) we wouldn't even need to configure the ingress for pod-to-pod communication and (c) the middleware applied at the ingress that strips the `file/` prefix would not be applied and thus the md5 sum service calling the file service would simply use `/upload` and not `/file/upload`.

### Lazy Instantiation of PVC

Some k3s items effectively use lazy instantiation. For example, if we HADN'T yet applied the deployment for the file service then our associated PVC would be waiting until needed:

```
$ kubectl describe pvc file-upload-pvc

...
Status:        Pending

...
Events:
  Type    Reason                Age                From                         Message
  ----    ------                ----               ----                         -------
  Normal  WaitForFirstConsumer  10s (x5 over 69s)  persistentvolume-controller  waiting for first consumer to be created before binding
```

The message above indicates the pvc won't be created until some k3s resource decides to use it. (This is the default behavior but is configurable in the yaml.)

Let's sanity check our persistent volume. First, let's make sure that our PVC is using the `file-upload-pv` that we set up:

```
$ kubectl get pvc
NAME              STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
file-upload-pvc   Bound    file-upload-pv   1Gi        RWO            local-path     <unset>                 5m16s
```

The `VOLUME` is `file-upload-pv` which is a good sign. But, let's check the PV to see where we expect to find data on the filesystem and actually look at that path:

```
$ kubectl get pv
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
file-upload-pv   1Gi        RWO            Retain           Bound    default/file-upload-pvc   local-path     <unset>                          3h35m
```

That didn't tell us anything about the path so let's drill down:

```
$ kubectl describe pv file-upload-pv
Name:            file-upload-pv
Labels:          <none>
Annotations:     pv.kubernetes.io/bound-by-controller: yes
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:    local-path
Status:          Bound
Claim:           default/file-upload-pvc
Reclaim Policy:  Retain
Access Modes:    RWO
VolumeMode:      Filesystem
Capacity:        1Gi
Node Affinity:   <none>
Message:         
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /usr/local/gigrouter/k3s/pv/file-server
    HostPathType:  DirectoryOrCreate
Events:            <none>
```

There, we can see the `Path` above. We could also look at:

```
$ kubectl get pv file-upload-pv -o yaml | grep -i path:
  hostPath:
    path: /usr/local/gigrouter/k3s/pv/file-server
```

In either case, we can see the path and now let's check it:

```
$ sudo ls -la /usr/local/gigrouter/k3s/pv/file-server
[sudo] password for gigrouter: 
total 24
drwxr-xr-x 3 root root  4096 Jan 22 01:05 .
drwxr-xr-x 3 root root  4096 Jan 22 01:05 ..
-rw-r--r-- 1 root root 12288 Jan 22 01:05 metadata.db
drwxr-xr-x 2 root root  4096 Jan 22 01:05 uploads
```

As we upload files, we can check the `uploads` directory to ensure files are appearing as expected.

For more info on PVs, see: [README-PV](./README-PV.md)

## Other Resources

### Docker References

The text above references a Docker example for background: [docker-hello-example](../docker-hello-example/README.md)

And, some additional exploration of Docker images based around example 2: [README-DOCKER-IMAGES](./README-DOCKER-IMAGES.md)
