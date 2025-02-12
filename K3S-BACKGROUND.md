# K3s Background

Below is some additional background on why we suggest using k3s for orchestration and containerization as well as some frequently asked questions.

The main documentation discusses the motivation behind the use of Kubernetes:
[Why Kubernetes](https://docs.gigrouter.space/book/v1.1.0/users_guide/software/container_orchestration.html#why-kubernetes)

The official base Kubernetes documentation can be found here: [Kubernetes Home](https://kubernetes.io/docs/home/)

The official k3s docs can be found here: [K3s Official Docs](https://rancher.com/docs/k3s/latest/en/)

See also [K3S-TIPS.md](./K3S-TIPS.md).

## Why run within k3s and not directly on the machine?

One of the goals of k3s is containerization. You can separate the Python version, requirements, dependencies and code of your application in its own pod environment. Additionally, this should result in a fairly portable set of yaml files to easily run your app in some other k3s environment.
