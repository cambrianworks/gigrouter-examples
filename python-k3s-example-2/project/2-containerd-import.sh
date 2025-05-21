#!/usr/bin/env bash

echo "Saving docker images then importing into k3s containerd..."

docker save file_service:latest -o file_service.tar
docker save md5sum_service:latest -o md5sum_service.tar

# For file_service
sudo k3s ctr images import file_service.tar

# For md5sum_service
sudo k3s ctr images import md5sum_service.tar
