#!/usr/bin/env bash

set -e

# This script installs and configures cuda-12.2 and nvidia-container-toolkit for usage on L4T R35.5.0 systems.

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi
# Verify we're on Ubuntu 20.04
# shellcheck disable=SC1091
if [[ -r /etc/os-release ]]; then
  # load NAME, VERSION_ID, PRETTY_NAME, etc.
  . /etc/os-release
  if [[ "$NAME" != "Ubuntu" || "$VERSION_ID" != "20.04" ]]; then
    echo "Error: This script only runs on L4T R35.5.0 (Ubuntu 20.04). Detected: $PRETTY_NAME" >&2
    exit 1
  fi
else
  echo "Error: Unable to determine OS version (missing /etc/os-release)" >&2
  exit 1
fi

# Add cuda apt source and install cuda 12

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/arm64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb
dpkg -i /tmp/cuda-keyring.deb
apt-get update
apt install -y cuda=12.2.2-1

# Add cuda-12 compat to ldcache
echo "/usr/local/cuda-12.2/compat" | tee /etc/ld.so.conf.d/988_cuda-12-compat.conf
ldconfig

# Install nvidia-container-toolkit

apt install -y nvidia-container-toolkit

# Modify nvidia-container-runtime config to look at cuda-12 libs

sed -i -e 's|/usr/lib/aarch64-linux-gnu/tegra/libcuda.so.1.1|/usr/local/cuda-12.2/compat/libcuda.so.1.1|g' /etc/nvidia-container-runtime/host-files-for-container.d/l4t.csv
sed -i -e 's|/usr/lib/aarch64-linux-gnu/libcuda.so|/usr/local/cuda-12.2/compat/libcuda.so|g' /etc/nvidia-container-runtime/host-files-for-container.d/l4t.csv
sed -i -e '\|/usr/lib/aarch64-linux-gnu/tegra/libcuda.so|d' /etc/nvidia-container-runtime/host-files-for-container.d/l4t.csv
sed -i -e 's|/usr/lib/aarch64-linux-gnu/tegra/libcuda.so.1|/usr/local/cuda-12.2/compat/libcuda.so.1|g' /etc/nvidia-container-runtime/host-files-for-container.d/l4t.csv

echo ""
echo "cuda-12.2 and nvidia-container-toolkit installed and configured to work together!!"
