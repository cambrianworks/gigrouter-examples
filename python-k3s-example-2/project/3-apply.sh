#!/usr/bin/env bash

echo "Applying all k3s manifest yaml files..."

# Show commands being executed in script to what output of each
# command relates to.
set -x

# Set up persistent volumes; we've set flags to auto-create directory if needed

kubectl apply -f k3s/pv.yaml
kubectl apply -f k3s/pvc.yaml

kubectl apply -f k3s/deployment-file-service.yaml
kubectl apply -f k3s/service-file-service.yaml

kubectl apply -f k3s/deployment-md5sum.yaml
kubectl apply -f k3s/service-md5sum.yaml

kubectl apply -f k3s/middleware.yaml
kubectl apply -f k3s/traefik-ingress.yaml
