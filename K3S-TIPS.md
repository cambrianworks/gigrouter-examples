# K3s Tips

Below are some quick tips for getting started with k3s. This assumes you already understand the basics of what k3s is and have scanned the [K3S-Background.md](./K3-BACKGROUND.md) file but want some quick hands-on tips.

This is intended to be the guide that gives you some of the background you wished you knew before ever getting started with k3s.

## Nodes and Clusters

In the general case, one goal of k3s is to be able to specify resources that can be deployed to any appropriate nodes in a cluster though, for the GigRouter, the default is simply a cluster of one single node.

The following are rough but adequate definitions:

host machine: This is the physical GigRouter host machine running Linux.

node: In general, nodes are 1:1 with host machines so the GigRouter will be configured for one k3s node.

cluster: A k3s cluster could include several nodes and then this complicates how resources are distributed, where mounted directories are distributed, exactly where particular services are running, etc. However, here we simply have a cluster of 1 node so some of the controls or settings for k3s are slightly simplified or just don't apply.

## kubectl api-resources

K3s includes support for numerous resource types and various ways of referring to the names. It can be confusing if you see `kubectl get services` versus `kubectl get service` versus `kubectl get svc` and why our yaml specification for a service uses `kind: Service`.

Note that [Example 1](./python-k3s-example-1/README.md) has a suggested [exercise](./python-k3s-example-1/EXERCISE-K3S-RESOURCES.md) that includes very similar information exploring configmaps.

Let's dig into this one for services!

```
$ kubectl api-resources -o wide | grep -iE "^services|shortnames"
NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND                               VERBS                                                        CATEGORIES
services                            svc          v1                                true         Service                            create,delete,deletecollection,get,list,patch,update,watch   all
```

Some takeaways from above are that we should use the string `Service` for `kind` but can query service resources using the name `services`, or short name `svc`, or the singularized name `service` (though this is not a best practice).

You can take a quick scan at all the resources:

```
kubectl api-resources -o wide
```

Let's look into a few more common ones for some variety:

```
$ kubectl api-resources -o wide | grep -E "^(NAME|services|configmaps|pods|namespaces|nodes|services|deployments)"
NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND                               VERBS                                                        CATEGORIES
configmaps                          cm           v1                                true         ConfigMap                          create,delete,deletecollection,get,list,patch,update,watch   
namespaces                          ns           v1                                false        Namespace                          create,delete,get,list,patch,update,watch                    
nodes                               no           v1                                false        Node                               create,delete,deletecollection,get,list,patch,update,watch   
pods                                po           v1                                true         Pod                                create,delete,deletecollection,get,list,patch,update,watch   all
services                            svc          v1                                true         Service                            create,delete,deletecollection,get,list,patch,update,watch   all
deployments                         deploy       apps/v1                           true         Deployment                         create,delete,deletecollection,get,list,patch,update,watch   all
nodes                                            metrics.k8s.io/v1beta1            false        NodeMetrics                        get,list                                                     
pods                                             metrics.k8s.io/v1beta1            true         PodMetrics                         get,list
```

What else do we see?

The names used are all plural. As with using the singular `configmap`, you can singularize any of the names to query but, again, this is not recommended as a best practice. However, the singular convention is often used and can make sense more intuitively if you are digging into and querying a specific `pod` (not multiple `pods`) but it's important to understand what forms are and are not supported.

The "kind" is capitalized and camel-cased. So, all the k3s yaml file specifications will contain `kind: SomeResourceKind`.

We'll get into "namespaces" soon but just note for now that `nodes` above indicates `false` but most of the resources indicate `true`.

The "verbs" include the list for supported commands passed to `kubectl COMMAND` such as `create`, `delete`, `get`, `patch`, `update`, etc.

## kubectl explain

Whenever you're creating a k3s yaml specification or reviewing one that was provided to you, there are a lot of fields to understand as well as times when you might wonder what fields are supported. `kubectl explain` can be very handy for this.

Note that [Example 1](./python-k3s-example-1/README.md) has a suggested [exercise](./python-k3s-example-1/EXERCISE-K3S-RESOURCES.md) that includes these same basics on `kubectl explain` almost verbatim.

This example simply drills down on settings for `configmaps` and we're significantly shortening the output just to highlight that the "explain" output addresses all the fields that we set in Example 1 for a configmap.

```
$ kubectl explain configmaps | grep -E "^  (apiVersion|data|kind|metadata)"
  apiVersion	<string>
  data	<map[string]string>
  kind	<string>
  metadata	<ObjectMeta>
```

Run on your own without the `grep` or with `--recursive` to quickly review some of the supported properties for config maps.

```
kubectl explain configmaps
```

You can see a lot more supported fields with `--recursive`.

```
kubectl explain --recursive configmaps
```

Try for some other k3s resources, such as pods:

```
kubectl explain --recursive pods
```

## Namespaces

For most resources in k3s, each is tied to a particular namespace. This simply lends itself to support of grouping like resources by function, provider, etc. If you ever don't specify a namespace then `default` is the literal default namespace that will be used. In a practical sense, many of the `kubectl` commands that you run regularly have an implied `-n default` and the yaml file specifications have an implied setting of:

```
metadata:
  namespace: default
```

Much of the infrastructure for k3s runs in the `kube-system` namespace.

It's very common to list the pods and here are 3 common commands.

This first one is equivalent to running `kubectl get pods -n default`:

```
$ kubectl get pods
NAME                          READY   STATUS    RESTARTS        AGE
mount-test-6cc99f7b47-v27fc   1/1     Running   51 (148m ago)   6d
```

Now, let's see an examle of what's running under `kube-system`:

```
$ kubectl get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS      AGE
coredns-7b98449c4-2qtrl                   1/1     Running   0             6d
local-path-provisioner-595dcfc56f-ttcnp   1/1     Running   0             6d
metrics-server-cdcc87586-gc2lc            1/1     Running   0             6d
svclb-traefik-5e34c6bb-4jkg8              2/2     Running   57 (6d ago)   65d
traefik-d7c9c5778-vnwwt                   1/1     Running   0             6d
```

We'll get into the details of some of these provided services later but here we just want to see that we've got some other pods running.

Certainly, there could be other pods running in different namespaces. We can use use `-A` to get **all** the pods (and this `-A` is commonly supported for other `kubectl` commands):

```
$ kubectl get pods -A
NAMESPACE     NAME                                      READY   STATUS    RESTARTS        AGE
default       mount-test-6cc99f7b47-v27fc               1/1     Running   51 (156m ago)   6d
kube-system   coredns-7b98449c4-2qtrl                   1/1     Running   0               6d
kube-system   local-path-provisioner-595dcfc56f-ttcnp   1/1     Running   0               6d
kube-system   metrics-server-cdcc87586-gc2lc            1/1     Running   0               6d
kube-system   svclb-traefik-5e34c6bb-4jkg8              2/2     Running   57 (6d ago)     65d
kube-system   traefik-d7c9c5778-vnwwt                   1/1     Running   0               6d
```

**IMPORTANT:** The `-A` switch resulted in an additional `NAMESPACE` column in the output. This can be very important if you are writing scripts to process the output.

You could try either of the following to see alternative output formats that might be more appropriate for readability or script processing.

json-formatted output:

```
kubectl get pods -o json
```

yaml-formatted output:

```
kubectl get pods -o yaml
```

As the `nodes` are really the top-level resources that host all the other resources, they are not tied to a namespace.

Here we don't see a namespace column:

```
w$ kubectl get nodes
NAME                STATUS   ROLES                  AGE   VERSION
k3s-1423522021480   Ready    control-plane,master   65d   v1.30.6+k3s1
```

## Wide -o Option

For many `kubectl` commands that produce columns of data, `-o wide` can often add additional useful information.

Examples:

Get pods with additional columns:

```
kubectl get pods -A -o wide
```

Get list of k3s supported api-resources with additional columns:

```
kubectl api-resources -o wide
```

Get list of persistent volume claims with additional columns:

```
kubectl get pvc -o wide
```

## Watch -w Option

Often, commands such as `kubectl get pods` are meant to list what services are currently running or what resources are deployed.

When supported, the `-w` option will "watch" the resources and add new lines as changes take place.

For example, most of the pods will show a status of "Running" but as you kill pods or launch them, you can see the status change with a command such as:

```
kubectl get pods -o wide -w
```

## Inspecting Status with get or describe

For checking k3s status or troubleshooting, it's very common to drill down using both variations `kubectl get` and `kubectl describe`.

In a nutshell, `kubectl describe` is especially handy for troubleshooting since it generally ends with an **Events:** section.

Take the following as an example:

```
$ kubectl describe pod mount-test-6cc99f7b47-v27fc | tail -n 6
Events:
  Type    Reason   Age                  From     Message
  ----    ------   ----                 ----     -------
  Normal  Pulled   27m (x53 over 6d1h)  kubelet  Container image "python:3.11-slim" already present on machine
  Normal  Created  27m (x53 over 6d1h)  kubelet  Created container python-app
  Normal  Started  27m (x53 over 6d1h)  kubelet  Started container python-app
```

Above we can see various checks and no apparent problems. However, we might see a failure or some condition that we are waiting on.

The `kubectl get` command is also quite flexible for querying resources and can be used to drill down quite effectively.

For example, look at this sequence:

```
$ kubectl get pods
NAME                          READY   STATUS    RESTARTS       AGE
mount-test-6cc99f7b47-v27fc   1/1     Running   52 (29m ago)   6d1h
```

Now that we see the general status, let's drill down on the listed pod.

```
$ kubectl get pod mount-test-6cc99f7b47-v27fc -o yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2025-01-31T00:37:19Z
...
```

Above will include many other properties and in the same format as the yaml specification.

Suppose we want to just pull out a particular field, perhaps in a script that wants to check the value of a field.

Here's an example:

```
$ kubectl get pod mount-test-6cc99f7b47-v27fc -o jsonpath="{.spec.terminationGracePeriodSeconds}"
30
```

We can see that the pod has a grace period of 30 seconds to quit when requested before it is forcefully stopped.

Here's another example where we can query the IP address in use by Example 1:

``` bash
kubectl get svc python-app -o jsonpath='{.spec.clusterIP}'
```

Sample output:

```
10.43.242.77
```

## kubectl apply, patch and delete

In general, when you want to update k3s resources, you'll issue one of `kubectl apply`, `kubectl patch` or `kubectl delete`. Another is `kubectl create` which is like an `apply` that first ensures the resource didn't exist.

Generally, you'll apply a yaml file with:

```
kubectl apply -f resourcefilename.yaml
```

You can delete the correspond resource(s) with various combinations such as:

```
kubectl delete -f resourcefilename.yaml
```

or

```
kubectl delete resourcetype resourcename
```

or

```
kubectl delete resourcetype1/resourcename1 resourcetype2/resourcename2
```

or (as an example of restarting all pods corresponding to the k3s built-in "local path provisioner" service)

```
kubectl delete pod -l app="local-path-provisioner" -n kube-system
```

If you've "applied" a yaml specification, you can edit the yaml and apply the changes by simply running apply again on the updated file:

```
kubectl apply -f resourcefilename.yaml
```

We can also "patch" a resource. We looked at terminationGracePeriodSeconds above on a pod and saw it was 30. For that specific pod, let's try patching this to 5 seconds:

```
$ kubectl patch pod mount-test-6cc99f7b47-v27fc -p '{"spec": {"terminationGracePeriodSeconds": 5}}'
The Pod "mount-test-6cc99f7b47-v27fc" is invalid: spec: Forbidden: pod updates may not change fields other than `spec.containers[*].image`,`spec.initContainers[*].image`,`spec.activeDeadlineSeconds`,`spec.tolerations` (only additions to existing tolerations),`spec.terminationGracePeriodSeconds` (allow it to be set to 1 if it was previously negative)
  core.PodSpec{
  	... // 3 identical fields
  	EphemeralContainers:           nil,
  	RestartPolicy:                 "Always",
- 	TerminationGracePeriodSeconds: &30,
+ 	TerminationGracePeriodSeconds: &5,
  	ActiveDeadlineSeconds:         nil,
  	DNSPolicy:                     "ClusterFirst",
  	... // 25 identical fields
  }
```

Our patch failed but the syntax shows how a patch could work and output troubleshooting is useful.

Here, the command was run in `bash` and we can see that the failed patch gave a non-zero exit status (by checking the special `$?` last exit status variable):

```
$ echo $?
1
```

We can update a live resource with our standard editor (`export EDITOR=vim`, for example) with a command like:

```
$ kubectl edit pod mount-test-6cc99f7b47-v27fc
Edit cancelled, no changes made.
```

Above, the editor was closed without making changes.

From this section, you should have a general understanding of how to create, delete and modify k3s resources.

**NOTE:** These changes are not guaranteed to persist across a reboot be immune by changes from other k3s tools. Some resources are fixed in k3s and will be reset to their defaults upon a reboot. For example, if you modified some properties of the k3s "local path provisioner" service and rebooted the computer, the defaults would be re-applied at startup. You'd need to review other documentation for a persistent configuration change to a k3s service. For GigRouter services, the directory `/etc/gigrouter/k3s` contains some configuration properties that are generally not intended to be changed manually and will be reapplied to their default state upon reboot. 

## Service Types

When you specify a k3s resource of `kind: Service` you must also configure the type of service to one of the following common types:

* LoadBalancer
* NodePort
* ClusterIP

Each is appropriate in different circumstances. There are releated resources such as `ingresses` and `endpoints` that you might also configure in combination with services. The detail here is designed just to give a very basic overview as a starting point.

`type: LoadBalancer` means the service will get exposed at some IP address assigned to the cluster. Roughly, each k3s node (computer on the cluster, here just one GigRouter) should get a private IP address and k3s has other private IP addresses to dole out (likely 192.168.x.y for the `node` and 10.a.b.c for various services on the `cluster`).

`LoadBalancer` is meant to be an eventual drop-in for various cloud providers BUT k3s defaults to using a service called Klipper that will function standalone for `LoadBalancer`.

If we use `NodePort` then we can't listen at some common ports such as `8080` but must choose a port in range `30000-32767`. This is generally appropriate for local testing or a quick proof-of-concept.

`ClusterIP` is the default service type (if type is not specified) then we can communicate within the cluster but not from a machine outside the cluster without additional ingress configuration.

[Example 2](./python-k3s-example-2/README.md) gives a basic setup that uses an ingress which lets you attach your http service to the k3s cluster and available at both standard http:// and https:// ports and some unique URL path to direct to your service. 

## Service Types Additional Drilldown

Launching and connecting to k3s TCP/IP services is important functionality to understand.

[Example 1](./python-k3s-example-1/README.md) showed an example of how to connect to a `LoadBalancer` service listening at port 8080.

Below are some other options here for accessing the service or exposing ports:

1. You can port forward to any given pod or service and then `localhost` will forward to the pod on specified port:

    The example below forwards `8090` to not conflict with existing use of port `8080`.

    ``` bash
    kubectl port-forward deployment/python-app 8090:8080
    ```

    You can now connect to `localhost:8090`. (The `port-forward` command runs until you hit CTRL-c to kill the port forward.)

    Or, to the pod:

    ``` bash
    $ kubectl get pods
    NAME                          READY   STATUS    RESTARTS   AGE
    python-app-6f874589dd-wmbg7   1/1     Running   0          16m

    $ kubectl port-forward python-app-6f874589dd-wmbg7 8090:8080
    ```

    In fact, you shouldn't even need to specify the `kind: Service` section in `deployment.yaml` if you want to go this route.

2. If you use `type: NodePort` instead of `type: LoadBalancer` then you are basically assigning a "port" to the "node" (main k3s IP for GigRouter though it would actually listen on all nodes in any cluster) but there are constraints:
    * You must specify a port in high range 30000+ (30000 to 32767)
    * You wouldn't use `NodePort` for more complicated cloud setups

    Here's an alternative snippet to use `NodePort` in the yaml:

```
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
    nodePort: 30080  # For NodePort, a port >= 30000
  type: NodePort  # versus LoadBalancer
```

With above, you can connect to many variations including `localhost:30080`, `local_ip_address:30080`, or `cluster_ip_address:8080`, or port forward to node and connect to `8080`.

3. Another option is to use the default `type: ClusterIP` which is generally reserved for intra-cluster communication or in combination with ingress configuration in the case of http endpoints. Use of ClusterIP and ingress setup is covered in [Example 2](./python-k3s-example-2/README.md).

## K3s Built-in Services

The following are all services built into k3s by default:

* `coredns`
* `local-path-provisioner`
* `metrics-server`
* `traefik`

You can see these in the k3s internals `kube-system` namespace when you run commands such as:

```
$ kubectl get pods -A
NAMESPACE     NAME                                      READY   STATUS    RESTARTS       AGE
default       python-app-6f874589dd-k2ld6               1/1     Running   0              45s
kube-system   coredns-7b98449c4-blbm9                   1/1     Running   0              19d
kube-system   local-path-provisioner-595dcfc56f-cqj8d   1/1     Running   0              19d
kube-system   metrics-server-cdcc87586-zsh2m            1/1     Running   0              4d20h
kube-system   svclb-python-app-30c6980b-kxd7c           1/1     Running   0              2m29s
kube-system   svclb-traefik-5e34c6bb-4jkg8              2/2     Running   41 (19d ago)   41d
kube-system   traefik-d7c9c5778-qsbxf                   1/1     Running   0              19d
```

#### `coredns`

Within k3s, you can connect to other services using the service name and it will be resolved similar to regular `DNS`. This might also be referred to by the name of `kube-dns` which can be important for portability in letting `coredns` be a specific implementation of a general kube dns service.

#### `local-path-provisioner`

If you need persistent storage, you can set up persistent volumes and the `local-path-provisioner` service provides this functionality.

#### `metrics-server`

This is an aggregator of resource usage.

#### `traefik`

Detailed more in example 2, `traefik` allows managing an ingress for http endpoints running within your k3s environment. You'll find that your k3s will by default listen on port 80 for http and at 443 for https though, without additional configuration, will run with a self-signed certificate and trigger some warnings.
