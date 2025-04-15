Make the ingress just listen on all kubelet hosts on 80 and 443 (so I can port-fwd to them or do keepalived or something)

Chart install:

```
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace --set controller.kind=DaemonSet --set controller.hostNetwork=true --set controller.daemonset.useHostPort=true
```

Next, we want cert-manager:

```
helm repo add jetstack https://charts.jetstack.io --force-update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.0 \
  --set crds.enabled=true

k apply -f cluster-issuer.staging.yaml
k apply -f cluster-issuer.yaml
```

Now, add TLS stuff to your Ingress - see `miniflux-ingress.yaml` for an example.

Check the thing:

```
kubectl get certifications -A
...
```
