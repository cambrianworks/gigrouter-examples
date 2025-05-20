#!/usr/bin/env bash

echo "This is a clean-up step to delete transient data and k3s resources..."

rm -f file_service.tar md5sum_service.tar
docker rmi md5sum_service:latest file_service:latest

kubectl delete ingress/multi-service-ingress middleware/strip-file-prefix svc/file-service deployments.apps/file-service svc/md5sum-service deploy/md5sum-service pvc/file-upload-pvc pv/file-upload-pv

HOST_PATH="/usr/local/gigrouter/k3s/pv/file-server"
echo ""
echo ""
echo "Checking host for files remaining from persistent volume"
echo "at: ${HOST_PATH}"
ls -laR "${HOST_PATH}"
echo ""
echo "You can manually remove any files at '${HOST_PATH}'"
echo "to remove files saved by service."
