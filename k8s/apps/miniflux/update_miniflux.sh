#!/bin/bash

# Our postgres password lives in a secret and I don't know how to get helm to do this a cleverer way (yet?)

export POSTGRES_PASS=`kubectl get secret -n miniflux postgres -o=jsonpath='{ .data.pass }' | base64 --decode`

# Note: The ingress for this service is managed outside the helm chart, see ../../infra/nginx-ingress/miniflux-ingress.yaml

helm upgrade miniflux oci://ghcr.io/gabe565/charts/miniflux \
  --install \
  --namespace miniflux \
  --set env.BASE_URL='https://home.andvari.net/rss' \
  --set postgresql.enabled='false' \
  --set env.DATABASE_URL="postgres://miniflux:${POSTGRES_PASS}@postgres.home.nomad.andvari.net/miniflux?sslmode=disable"
