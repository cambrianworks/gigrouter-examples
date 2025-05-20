# Example K3s Applications

This page links to examples specifically designed to run in a `k3s` environment on GigRouter devices. For broad readability, examples are Python-based and highlight key features such as launching services, container communication, persistent storage, and building images.

**Note:** Most of the steps in these examples should run on any standard Linux machine under a `bash` shell with the following (representative but non-exhaustive list of) tools installed: `k3s` `stern` `curl` `docker`

## Prerequisites

Before starting, a basic understanding of k3s is useful. See the following:
- [Why Kubernetes](https://docs.gigrouter.space/book/v2.2.0/users_guide/software/container_orchestration.html#why-kubernetes)
- [K3s Overview](./README-K3S-OVERVIEW.md)

## Example 1: HTTP Addition Server

- Path: [`python-k3s-example-1`](./python-k3s-example-1/README.md)
- Description: A simple Python HTTP service that performs addition
- Concepts:
  - Pod deployment in `k3s`
  - Using `LoadBalancer` and exposing port 8080
- Exercises:
  - Extend the service to support a `/multiply` endpoint
  - [Exploring K3s Resources](./python-k3s-example-1/EXERCISE-K3S-RESOURCES.md) to investigate `kubectl` sub-commands: `api-resources` and `explain`

## Docker Primer

- Path: [`docker-hello-example`](./docker-hello-example/README.md)
- Description: A minimal Docker example to get familiar with images prior to exporting them for use in `k3s`

## Example 2: File Upload and MD5 Sums across Services

- Path: [`python-k3s-example-2`](./python-k3s-example-2/README.md)
- Description: A multi-service application demonstrating:
  - HTTP file uploads with Flask
  - HTTP endpoint for md5sum
  - Metadata storage using SQLite
  - Use of persistent volumes
  - Traefik ingress configuration (http:// and https:// )
  - Custom Docker images imported into `containerd` for `k3s`
- [Exercises](./python-k3s-example-2/README-EXERCISES.md)
  - Explore extracting data from the file server's sqlite database
  - Demonstrate copying files in/out of a pod
  - Execute a bash shell in pod to demonstrate general debugging capabilities
  - Make replicas of the md5sum service
- Documentation:
  - [Persistent Volume Primer](./python-k3s-example-2/README-PV.md)
  - [Ingress](./python-k3s-example-2/README-INGRESS.md)

These examples aim to provide a practical foundation for deploying and customizing services within a `k3s` cluster on GigRouter.
