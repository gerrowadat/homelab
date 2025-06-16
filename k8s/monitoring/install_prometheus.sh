#!/bin/bash

# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# kubectl add namespace monitoring
helm upgrade -i prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --set alertmanager.persistence.storageClass="fast-nfs" \
    --set server.persistentVolume.storageClass="fast-nfs"
