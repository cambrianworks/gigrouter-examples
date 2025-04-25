#!/usr/bin/env bash

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

# Test deviceQuery

cd Samples/1_Utilities/deviceQuery
make -j8
sudo docker run --rm --runtime=nvidia --gpus all -v .:/test nvidia/cuda:12.2.0-base-ubuntu20.04 bash -c "cd /test && ./deviceQuery"

# Test transpose

cd ../6_Performance/transpose
make -j8
sudo docker run --rm --runtime=nvidia --gpus all -v .:/test nvidia/cuda:12.2.0-base-ubuntu20.04 bash -c "cd /test && ./transpose"
