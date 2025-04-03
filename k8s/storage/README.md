# Storage Setup

Notes from setting up Storage classes:

```
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

kubectl create namespace nfs-subdir-external-provisioner

# New machine with SSD
helm install fast-nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace nfs-subdir-external-provisioner -f fast-nfs.values

# bockety old spinny NAS
helm install slow-nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace nfs-subdir-external-provisioner -f slow-nfs.values

```

testclaim.yaml is for seeing if things are plumbed, but the pods will shit the bed if so anyway.
