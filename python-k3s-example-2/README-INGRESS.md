# K3s Ingress

Example 2 configures a k3s ingress for directing http:// and https:// traffic to the appropriate service (pod) based on path matching. Paths that begin with `/md5` are routed to the md5sum service and those that begin with `/file` are routed to the file service. Additionally, middleware is configured to strip the `/file` prefix prior to forwarding.

K3s official docs including Traefik: [Networking Services](https://docs.k3s.io/networking/networking-services)

Middleware that includes support to strip prefix: [StripPrefix](https://doc.traefik.io/traefik/middlewares/http/stripprefix/)

## Traefik Ingress Config

Below is the Traefik ingress config for example 2.

<!-- inline: project/k3s/traefik-ingress.yaml -->
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-service-ingress
  namespace: default  # ensure this matches your namespace
  annotations:
    # Note: Some instructions use "default/" instead of "default-" but that fails to
    # work and logs errors in traefik.
    traefik.ingress.kubernetes.io/router.middlewares: default-strip-file-prefix@kubernetescrd
spec:
  rules:
  - http:
      paths:
      - path: /md5
        pathType: Prefix
        backend:
          service:
            name: md5sum-service
            port:
              number: 80
      - path: /file
        pathType: Prefix
        backend:
          service:
            name: file-service
            port:
              number: 80

```
<!-- endinline -->

From this, we can see:
* Our service type plus service name is: `ingress/multi-service-ingress`
* We are watching for prefix `/md5` and `/file`
* These are respectively forwarded to `md5sum-service:80` and `file-service:80`

The Traefik endpoint will listen on standard http port 80 as wels as https port 443 in its default config. However, the default security certificate is self-signed and the example 2 documentation discussed, for example, having to use the `--insecure` option with `curl`. This README doesn't discuss any advanced configuration to update to a commercial certificate.

## Questions about the Config

A couple immediate questions that arise from reviewing the config are below.

### IP Address for Ingress

Q: How do I access this main ingress controller? What IP address should I use and how accessible is it?

The node IP can be used.

All the `curl` lines in the example were performed on the k3s node itself and used `localhost`. However, we can drill down to find some info on the node IP. From the output of:

```
kubectl describe ingress/multi-service-ingress
```

we can see:

```
Name:             multi-service-ingress
Labels:           <none>
Namespace:        default
Address:          192.168.86.34
Ingress Class:    traefik
Default backend:  <default>
Rules:
  Host        Path  Backends
  ----        ----  --------
  *           
              /md5    md5sum-service:80 (10.42.0.61:5001)
              /file   file-service:80 (10.42.0.60:5000)
Annotations:  traefik.ingress.kubernetes.io/router.middlewares: default-strip-file-prefix@kubernetescrd
Events:       <none>
```

Although the "Address" will be different on your machine, this should be the host IP of your k3s node. It should match the output from the following command on your machine:

```
kubectl describe node | grep IP
```

Here, the output is:

```
  InternalIP:  192.168.86.34
```

Depending on your internal routing and firewall rules, an external machine should be able to access your services at both:

http://InternalIP and

https://InternalIP

### What ports are used?

Q: The ingress is forwarding to port 80 for each service. I thought the file service was listening at port 5000 and the md5 sum service at port 5001 so where does port 80 come from?

There are a couple levels of indirection here with ingress forwarding to the service which forwards to the pod. Let's try to clear this up.

```
$ kubectl get svc
NAME             TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)          AGE
file-service     ClusterIP      10.43.101.19    <none>          80/TCP           22m
kubernetes       ClusterIP      10.43.0.1       <none>          443/TCP          163d
md5sum-service   ClusterIP      10.43.157.176   <none>          80/TCP           22m
python-app       LoadBalancer   10.43.200.74    192.168.86.34   8080:32315/TCP   126d
```

We can see both `svc/file-service` and `svc/md5sum-service` are listening at port 80.

Let's just look at the `md5sum-service` as an example. Here's the config:

`service-md5sum.yaml`

<!-- inline: project/k3s/service-md5sum.yaml -->
```
apiVersion: v1
kind: Service
metadata:
  name: md5sum-service
spec:
  type: ClusterIP
  selector:
    app: md5sum-service
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5001
```
<!-- endinline -->

And, here's what an example `describe` looks like:

```
$ kubectl describe svc/md5sum-service
Name:              md5sum-service
Namespace:         default
Labels:            <none>
Annotations:       <none>
Selector:          app=md5sum-service
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.43.157.176
IPs:               10.43.157.176
Port:              <unset>  80/TCP
TargetPort:        5001/TCP
Endpoints:         10.42.0.61:5001
Session Affinity:  None
Events:            <none>
```

We can see the service runs at port 80 and then directs to targetPort 5001. The routing of the traffic looks like:

Ingress (http 80 and https 443) for (`/md5`) --> `svc/md5sum-service:80` --> `deploy/md5sum-service:5001`

## Middleware Config

<!-- inline: project/k3s/middleware.yaml -->
```
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: strip-file-prefix
  namespace: default   # ensure the namespace is correct
spec:
  stripPrefix:
    # ingress watches for /file/upload, /file/files, and /file/download AND
    # uses leading /file to direct anything with that to file-service BUT
    # should strip leading "/file" when passing on to underlying service
    prefixes:
      - /file
```
<!-- endinline -->

Note above that `namespace: default` and you'll need to update or create an additional yaml file if you want to strip prefixes for services built in other namespaces.

As configured above, this middleware does nothing more than remove the `/file` prefix from the URL at the ingress before forwarding to the file service.

For example, for this URL: `https://localhost/file/files`

The file service will simply see `/files` instead of `/file/files`. This is primarily a design choice since the file service would otherwise have to respond to each of `/file/upload`, `/file/download`, and `/file/files` instead of just `/upload`, `/download`, and `/files`.

For the md5sum service, `/md5` is watched for at the ingress and `/md5` is passed as is to the md5sum service so there is no prefix stripping defined for this service.
