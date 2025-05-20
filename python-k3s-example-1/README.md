# GigRouter Simple K3s Python Example

## Use Case

This example shows how a simple Python application can be run within the GigRouter's k3s cluster. (In this case, the **cluster** is the single **node** running on the GigRouter.)

## Application

This is a simple web server example application written in Flask and would be an appropriate starting point for a Python service intending to have a simple REST interface.

The application also serves the purposes of deploying an application to k3s, checking status, making calls to it, customizing it, shutting it down, exposing TCP/IP ports, specifying a base Python image and specifying required Python libraries in a `requirements.txt` file.

## K3s Background

For information on why we encourage use of k3s on the GigRouter for containerization and orchestration, see [Container Orchestration](https://docs.gigrouter.space/book/v2.2.0/users_guide/software/container_orchestration.html) of the GigRouter User Docs as well as some of the READMEs in the parent directory including [README-K3S-OVERVIEW.md](../README-K3S-OVERVIEW.md).

## Example 1 - All in One

In this simplest case, we'll inline the entire Python application and `requirements.txt` file into a k3s yaml file and thus avoid the complexity of using Docker to customize a Python base image and then export this image for use with k3s.

### The parts

For this example, there are 3 k3s building blocks spread across 2 files:

#### [app-config.yaml](./app-config.yaml)

<!-- inline: app-config.yaml -->
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: python-app-config
data:
  app.py: |
    from flask import Flask, request, jsonify

    app = Flask(__name__)

    @app.route("/")
    def home():
        return "Hello, k3s World!"

    @app.route("/add", methods=["GET"])
    def add():
        try:
            operand1 = float(request.args.get("a", 0))
            operand2 = float(request.args.get("b", 0))
            result = operand1 + operand2
            return jsonify({"operand1": operand1, "operand2": operand2, "result": result})
        except ValueError:
            return jsonify({"error": "Invalid input. Please provide numbers for arguments a and b."}), 400

    if __name__ == "__main__":
        app.run(host="0.0.0.0", port=8080)
  requirements.txt: |
    flask

```
<!-- endinline -->

This specifies a `ConfigMap`. Often, this could set environment variables or populate a local configuration but here we will specify entire files: a Python program as `app.py` and dependent libraries as `requirements.txt`.

The top part of the yaml file is boilerplate for specifying a k3s resource where `kind` must be a supported resource type and we've chosen an appropriate `name` for the resource.

**K3s Tip:** See [K3S-TIPS.md](../K3S-TIPS.md) for some additional background on k3s. The [K3s Resources Exercise](./EXERCISE-K3S-RESOURCES.md) uses `kubectl api-resources` to show some properties of the `ConfigMap` resource and `kubectl explain configmaps` to understand some of the properties that can be set for a `ConfigMap`.

**YAML Note:** The `|` above is a "literal block scaler" which means **most** indentation and newlines of the subsequent lines are preserved exactly as-is. The above blocks have a base indent of 4 spaces which will be stripped. You might also see `|-` which just strips the final newline or `>` (or `>+` or `>-`) which is a "folding scalar" that will normalize all whitespace (including newlines) into a single line with normal space characters (with or without the final newline).

**Python Note:** Python, as a language, uses "enforced indentation" which is suggested to be multiples of 4 spaces by default but any consistent whitespace for indented blocks is required by the interpreter. The interpreter will throw an `IndentationError` if, for example, you have an `if`/`else` block and these keywords do not have the exact same indentation.

#### [deployment.yaml](./deployment.yaml)

<!-- inline: deployment.yaml -->
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: python-app
  template:
    metadata:
      labels:
        app: python-app
    spec:
      containers:
      - name: python-app
        image: python:3.11-slim  # Use a pre-built Python image
        command: ["/bin/sh", "-c"]
        args:
        - |
          pip install --no-cache-dir -r /app/requirements.txt &&
          python /app/app.py
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: app-volume
          mountPath: /app
      volumes:
      - name: app-volume
        configMap:
          name: python-app-config
---
apiVersion: v1
kind: Service
metadata:
  name: python-app
spec:
  selector:
    app: python-app
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
  type: LoadBalancer

```
<!-- endinline -->

Here, we've specified both a `Deployment` and a `Service` where the `---` on a line on its own separates the resources and allows specification of multiple resources in a single file.

`kind: Deployment` specifies a container to run based on a publicly available Python image and indicates to mount the `ConfigMap` (which means the `ConfigMap` should be made available before applying the `deployment.yaml` file)

`kind: Service` specifies that the above deployment is a network service, `port: 8080` indicates the port the service is exposed at for external connections and `targetPort: 8080` is a more arbitrary port indicating where the service is listening internally

### TCP/IP Decisions

The decision for the example is to standardize on port `8080` for the web server as that is fairly standard and doesn't conflict with the default port 80 which is often in use. We also want to be able to call our server from machines on the GigRouter's network that aren't the GigRouter itself. We also want to keep things simple and not worry about configuring an ingress for this example.

We've selected `type: LoadBalancer` to suit our needs but you can look in [K3S-TIPS.md](../K3S-TIPS.md) for information on other types such as `NodePort` and `ClusterIP`.

**Caution:** The intuition that the service should be available at `localhost:8080` will likely work from the GigRouter but this might take a few seconds to be available.

For information about the service associated with the `LoadBalancer` for `python-app`, run:

``` bash
kubectl get svc python-app
```

Sample output:

```
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)          AGE
python-app   LoadBalancer   10.43.242.77   192.168.86.34   8080:32170/TCP   11m
```

### The files

As this is a rather short example, the full contents of both yaml files were inlined above but they are also available at these links:

[app-config.yaml](./app-config.yaml)

[deployment.yaml](./deployment.yaml)

### Deploy and Test

Below shows a sample session of launching and querying the service with `curl`.

To launch the application, you can simply apply the yaml files in succession. However, don't run this just yet as the longer command below will also immediately check and display status of the launched resources.

This command would apply the k3s resources in `app-config.yaml` (hold-off running):

```
kubectl apply -f app-config.yaml
```

This command would apply the k3s resources in `deployment.yaml` (hold-off running):

```
kubectl apply -f deployment.yaml
```

"Applying" the yaml files should be all that it takes to launch your application in k3s! However, assuming you haven't launched yet, the following command will apply both yaml files in immediate succession and then query k3s so we can get a glimpse at the **initial** status.

Run this command to launch and check initial state:

``` bash
kubectl apply -f app-config.yaml && kubectl apply -f deployment.yaml && kubectl get configmaps && kubectl get pods && kubectl get svc
```

Sample output:

```
configmap/python-app-config created
deployment.apps/python-app created
service/python-app created
NAME                DATA   AGE
kube-root-ca.crt    1      21d
python-app-config   2      0s
NAME                          READY   STATUS              RESTARTS   AGE
python-app-6f874589dd-wmbg7   0/1     ContainerCreating   0          1s
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP      10.43.0.1      <none>        443/TCP          21d
python-app   LoadBalancer   10.43.242.77   <pending>     8080:32170/TCP   1s
```

That was a lot on one line but serves to show that the pod takes a bit of time to start up. The point above is to see a "status" of `ContainerCreating` as well as a `<pending>` for the `LoadBalancer`. This is to illustrate both that you querying the status is important and to not assume that applied resources are available immediately.

Wait a few seconds and try again:

``` bash
kubectl get pods && kubectl get svc
```

Sample output:

```
NAME                          READY   STATUS    RESTARTS   AGE
python-app-6f874589dd-wmbg7   1/1     Running   0          2m26s
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)          AGE
kubernetes   ClusterIP      10.43.0.1      <none>          443/TCP          21d
python-app   LoadBalancer   10.43.242.77   192.168.86.34   8080:32170/TCP   2m26s
```

Above shows that the pod is now `Running` and the listed IP addresses indicate where the service is accessible (where `EXTERNAL-IP` should match the localhost address).

**NOTE:** You will likely see many other pods and services running. We're mainly focused on those matching `python-app`.

Simple query, just to see if we can access the service:

``` bash
curl localhost:8080
```

Sample output:

``` bash
$ curl localhost:8080
Hello, k3s World!
```

Looks good! Let's add some numbers:

```
curl "localhost:8080/add?a=12.5&b=5"
```

Sample output:

``` bash
$ curl "localhost:8080/add?a=12.5&b=5"
{"operand1":12.5,"operand2":5.0,"result":17.5}
```

**Important:** The `curl` line above must be quoted or the `&` escaped as `\&` to avoid the `&` being treated as running the portion of the command leading up to the `&` in the background (and then separately running `b=5` in the foreground).

### Check the logs:

``` bash
$ kubectl get pods
NAME                          READY   STATUS    RESTARTS   AGE
python-app-6f874589dd-wmbg7   1/1     Running   0          29m

$ kubectl logs --tail 10 python-app-6f874589dd-wmbg7
```

**TIP:** The `k3s-cw-deployment` Debian package enables k3s auto-completion in `bash` by default. Hence, you can `<TAB>-complete` the above command just by typing:

``` bash
$ kubectl logs --tail 10 python-app-6<TAB>
```

Sample output:

```
Press CTRL+C to quit
10.42.0.1 - - [24/Dec/2024 00:09:22] "GET / HTTP/1.1" 200 -
10.42.0.235 - - [24/Dec/2024 00:09:28] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [24/Dec/2024 00:23:29] "GET / HTTP/1.1" 200 -
10.42.0.235 - - [24/Dec/2024 00:29:57] "GET / HTTP/1.1" 200 -
10.42.0.235 - - [24/Dec/2024 00:31:44] "GET /add HTTP/1.1" 200 -
10.42.0.235 - - [24/Dec/2024 00:32:18] "GET /add&a=12.5&b=5 HTTP/1.1" 404 -
10.42.0.235 - - [24/Dec/2024 00:32:30] "GET /add?a=12.5&b=5 HTTP/1.1" 200 -
10.42.0.235 - - [24/Dec/2024 00:33:33] "GET /add?a=12.5 HTTP/1.1" 200 -
10.42.0.235 - - [24/Dec/2024 00:33:43] "GET /add?a=12.5&b=5 HTTP/1.1" 200 -
```

Even better, if you want color-coded output and pattern matching against strings on the command line, you can perform the following if you've installed `stern` which is provided by default in the `stern-cw` package:

``` bash
$ stern --tail 10 python-app
```

Sample output:

```
+ python-app-6f874589dd-wmbg7 › python-app
python-app-6f874589dd-wmbg7 python-app Press CTRL+C to quit
python-app-6f874589dd-wmbg7 python-app 10.42.0.1 - - [24/Dec/2024 00:09:22] "GET / HTTP/1.1" 200 -
python-app-6f874589dd-wmbg7 python-app 10.42.0.235 - - [24/Dec/2024 00:09:28] "GET / HTTP/1.1" 200 -
python-app-6f874589dd-wmbg7 python-app 127.0.0.1 - - [24/Dec/2024 00:23:29] "GET / HTTP/1.1" 200 -
python-app-6f874589dd-wmbg7 python-app 10.42.0.235 - - [24/Dec/2024 00:29:57] "GET / HTTP/1.1" 200 -
python-app-6f874589dd-wmbg7 python-app 10.42.0.235 - - [24/Dec/2024 00:31:44] "GET /add HTTP/1.1" 200 -
python-app-6f874589dd-wmbg7 python-app 10.42.0.235 - - [24/Dec/2024 00:32:18] "GET /add&a=12.5&b=5 HTTP/1.1" 404 -
python-app-6f874589dd-wmbg7 python-app 10.42.0.235 - - [24/Dec/2024 00:32:30] "GET /add?a=12.5&b=5 HTTP/1.1" 200 -
python-app-6f874589dd-wmbg7 python-app 10.42.0.235 - - [24/Dec/2024 00:33:33] "GET /add?a=12.5 HTTP/1.1" 200 -
python-app-6f874589dd-wmbg7 python-app 10.42.0.235 - - [24/Dec/2024 00:33:43] "GET /add?a=12.5&b=5 HTTP/1.1" 200 -
```

### Customize the example

Let's both add another method to our simple service and see how to deploy these updates.

With the `add` example as a reference, what would it take to support a `multiply` call? Add the following lines to `app-config.yaml` right after the `add` method:

```
    @app.route("/multiply", methods=["GET"])
    def multiply():
        try:
            operand1 = float(request.args.get("a", 0))
            operand2 = float(request.args.get("b", 0))
            result = operand1 * operand2
            return jsonify({"operand1": operand1, "operand2": operand2, "result": result})
        except ValueError:
            return jsonify({"error": "Invalid input. Please provide numbers for arguments a and b."}), 400
```

Note that this is effectively the same pattern as the `add` method with slight changes.

Check the [Flask Quickstart](https://flask.palletsprojects.com/en/latest/quickstart/) documentation to support using `POST` instead of `GET`, returning results other than `json`, etc.

After making the above changes to `app-config.yaml`, k3s is still running the previous version of the code. To update the example running in k3s, you need to `apply` the new new yaml file:

```
$ kubectl apply -f app-config.yaml
configmap/python-app-config configured
```

You also need to relaunch the service for it to see the changes. The type of our service is a `Deployment` which has a property that it will automatically restart if we simply delete it:

```
$ kubectl delete pods python-app-6<TAB>
pod "python-app-6f874589dd-wmbg7" deleted
```

Above both illustrates the property that the deployment will recreate deleted pods and demonstrates the k3s command completion for bashrc which should be supported automatically with our installer.

A more controlled restart without requiring the special identifier is also given below:

```
$ kubectl rollout restart deployment/python-app
deployment.apps/python-app restarted
```

There are some other positive properties of this method. With the delete, our service is unavailable until the automatic recreation of the delete completes. In the other case, pod(s) are not deleted until a suitable replacement has started and is ready.

Below shows some `get pods` calls with time time elapsed in the middle to see the new pod comes before the old one is deleted:

```
$ kubectl rollout restart deployment/python-app && kubectl get pods
deployment.apps/python-app restarted
NAME                          READY   STATUS              RESTARTS        AGE
python-app-57846cc555-c5gjh   1/1     Running             0               4m15s
python-app-6d6d4bdb6-n9wdl    0/1     ContainerCreating   0               0s

$ kubectl get pods
NAME                          READY   STATUS        RESTARTS        AGE
python-app-57846cc555-c5gjh   1/1     Terminating   0               4m17s
python-app-6d6d4bdb6-n9wdl    1/1     Running       0               2s

$ kubectl get pods
NAME                          READY   STATUS    RESTARTS        AGE
python-app-6d6d4bdb6-n9wdl    1/1     Running   0               3m48s
```

In either case, when a new pod is started, you'll see the new pod gets a new unique identifier.

Now, can you multiply?

```
$ curl localhost:8080/multiply?a=3\&b=7
{"operand1":3.0,"operand2":7.0,"result":21.0}
```

Success!

Try making any other changes you'd like to test.

### Shut everything down

Remove the services from k3s with the following commands:

``` bash
kubectl delete svc python-app
kubectl delete deploy python-app
kubectl delete cm python-app-config
```

Or, use `delete` by itself with fully qualified names:

``` bash
$ kubectl delete svc/python-app deploy/python-app cm/python-app-config
```

## K3S additional drilldown

### Unspoken `default` namespace

For simplicity, all of the `kubectl` commands above never specified `-n namespace` and therefore used the default namespace which is literally `default` by default.

Much of k3s internals use a `kube-system` namespace. Let's run `get pods` but with `-A` for "all namespaces":

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

### `LoadBalancer` `svclb`

There's a 2nd version of `python-app` with `svclb` prepended. Let's try to see what this is:

```
$ kubectl -n kube-system logs -f svclb-python-app-30c6980b-kxd7c

...
+ iptables -t filter -I FORWARD -s 0.0.0.0/0 -p TCP --dport 8080 -j ACCEPT
+ echo 10.43.200.74+ 
grep -Eq :
+ cat /proc/sys/net/ipv4/ip_forward
+ '[' 1 '==' 1 ]
+ iptables -t filter -A FORWARD -d 10.43.200.74/32 -p TCP --dport 8080 -j DROP
+ iptables -t nat -I PREROUTING -p TCP --dport 8080 -j DNAT --to 10.43.200.74:8080
+ iptables -t nat -I POSTROUTING -d 10.43.200.74/32 -p TCP -j MASQUERADE
+ '[' '!' -e /pause ]
+ mkfifo /pause
```

This "service" "lb" is the default built into k3s for `LoadBalancer`! It's setting things up to listen to port 8080 and was automatically created when we set the type of our service to `LoadBalancer` and left load balancer to use the k3s default. We get a load balancer pod for each service we indicate uses `LoadBalancer`.

### Other k3s-specific pods

The k3s services for `coredns`, `local-path-provisioner`, `metrics-server` and `traefik` have some additional notes in [K3S-TIPS.md](../K3S-TIPS.md).

## Summary

Now you've launched a Python web server in k3s and queried it. You could extend this example to support other simple server use cases.