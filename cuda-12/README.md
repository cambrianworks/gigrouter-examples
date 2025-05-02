# CUDA 12.2 Installation and Usage

This doc has instructions for installing and configuring CUDA 12.2 & nvidia-container-toolkit on GigRouters running L4T R35.5.0. Both of these pieces of software are necessary for running containerized cuda-12 workloads.

## Quick Start

### Installing CUDA 12.2 and nvidia container runtime

The `install-cuda12.sh` script will install both `cuda-12.2` and `nvidia-container-toolkit`. It will also perform a few configuration steps so that the `nvidia-container-runtime` points at cuda-12.2 instead of the system default (cuda-11.4).

Copy the `install-cuda12.sh` script over to your GigRouter and run as root:

```bash
sudo ./install-cuda12.sh
```

This script will do the following:
- Add a CUDA apt source
- Install cuda-12.2
- Add cuda-12.2 compatability libs to ldcache
- Install nvidia-container-toolkit
- Configure the nvidia-container-runtime to point at cuda-12.2 instead of the system default (cuda-11.4)

### Verifying CUDA 12.2 is working

After the installation completes you can use the `verify-cuda12-docker.sh` script to verify cuda-12.2 is installed and accessible from docker containers.

Copy the `verify-cuda12-docker.sh` script over to your GigRouter and run:

```bash
./verify-cuda12-docker.sh
```

This script will do the following:
- Install docker
- Give docker access to the nvidia-container-runtime
- Clone the [cuda-samples repo](https://github.com/NVIDIA/cuda-samples)
- Build and run the `deviceQuery` sample under the `nvidia/cuda:12.2.0-base-ubuntu20.04` docker image
- Build and run the `transpose` sample under the `nvidia/cuda:12.2.0-base-ubuntu20.04` docker image

### Using CUDA 12.2 under Docker

CUDA is accessible under Docker (or other container runtimes) thanks to the nvidia-container-runtime.

Before running containerized workloads you'll need to configure the runtime. The following will configure docker:

```bash
sudo nvidia-ctk runtime continure --runtime=docker
sudo systemctl restart docker
```

Other container engines can be configured by following [these instructions](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#configuration).

You can run a dockerized workload by using the following flags: `--runtime=nvidia --gpus all`, like so:
```bash
sudo docker run --rm --runtime=nvidia --gpus all  nvidia/cuda:12.2.0-base-ubuntu20.04 <workload>
```

See [here](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/sample-workload.html#running-a-sample-workload) for instructions for running CUDA workloads under other container engines.
