#!/bin/bash

# Our postgres password lives in a secret and I don't know how to get helm to do this a cleverer way (yet?)

export POSTGRES_PASS=`kubectl get secret -n miniflux postgres -o=jsonpath='{ .data.pass }' | base64 --decode`

helm upgrade miniflux oci://ghcr.io/gabe565/charts/miniflux \
  --install \
  --namespace miniflux \
  --set postgresql.enabled='false' \
  --set env.DATABASE_URL="postgres://miniflux:${POSTGRES_PASS}@postgres.home.nomad.andvari.net/miniflux?sslmode=disable"
