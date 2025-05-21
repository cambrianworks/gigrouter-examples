#!/usr/bin/env bash

# This is just to inspect what we created in k3s.
echo "Reviewing the k3s resources we created..."
echo "(This step is optional but would help highlight errors.)"

# Show commands being executed by script to easily see what output
# is associated with.
set -x

# Check persistent volumes
kubectl get pv file-upload-pv
kubectl describe pv file-upload-pv
kubectl get pvc file-upload-pvc
kubectl describe pvc file-upload-pvc

# Get some info on the ingress
kubectl get middleware/strip-file-prefix
kubectl get ingress/multi-service-ingress
kubectl describe ingress/multi-service-ingress

# Check services and deployments
# For more info use "describe" instead of "get" or use option "-o yaml"
kubectl get deploy/file-service
kubectl get svc/file-service
kubectl get deploy/md5sum-service
kubectl get svc/md5sum-service
