#!/usr/bin/env bash

set -e

# Install docker

sudo apt install -y docker.io

# Configure docker with nvidia-container-runtime toolkit

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Grab cuda-samples for sample workloads

cd ~
git clone https://github.com/NVIDIA/cuda-samples.git
cd cuda-samples
git checkout v12.2

# Build samples

make -j8 PROJECTS=Samples/1_Utilities/deviceQuery/Makefile
make -j8 PROJECTS=Samples/6_Performance/transpose/Makefile

# Test deviceQuery

sudo docker run --rm --runtime=nvidia --gpus all -v ./bin/aarch64/linux/release:/test nvidia/cuda:12.2.0-base-ubuntu20.04 bash -c "cd /test && ./deviceQuery"

# Test transpose

sudo docker run --rm --runtime=nvidia --gpus all -v ./bin/aarch64/linux/release:/test nvidia/cuda:12.2.0-base-ubuntu20.04 bash -c "cd /test && ./transpose"

echo ""
echo "Verified CUDA examples successfully ran under docker container!!"
echo "You may choose to explore other examples or remove CUDA examples directory: ~/cuda-samples"
