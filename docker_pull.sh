#!/bin/bash
images=(kube-controller-manager-amd64 etcd-amd64 k8s-dns-sidecar-amd64 kube-proxy-amd64 kube-apiserver-amd64 kube-scheduler-amd64 pause-amd64 k8s-dns-dnsmasq-nanny-amd64 k8s-dns-kube-dns-amd64)
for imageName in ${images[@]} ; do
 docker pull champly/$imageName
 docker tag champly/$imageName gcr.io/google_containers/$imageName
 docker rmi champly/$imageName
done
