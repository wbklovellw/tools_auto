#!/bin/bash
docker tag gcr.io/google_containers/etcd-amd64 gcr.io/google_containers/etcd-amd64:3.0.17 && \
docker rmi gcr.io/google_containers/etcd-amd64 && \
docker tag gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64 gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:1.14.5 && \
docker rmi gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64 && \
docker tag gcr.io/google_containers/k8s-dns-kube-dns-amd64 gcr.io/google_containers/k8s-dns-kube-dns-amd64:1.14.5 && \
docker rmi gcr.io/google_containers/k8s-dns-kube-dns-amd64 && \
docker tag gcr.io/google_containers/k8s-dns-sidecar-amd64 gcr.io/google_containers/k8s-dns-sidecar-amd64:1.14.2 && \
docker rmi gcr.io/google_containers/k8s-dns-sidecar-amd64 && \
docker tag gcr.io/google_containers/kube-apiserver-amd64 gcr.io/google_containers/kube-apiserver-amd64:v1.7.5 && \
docker rmi gcr.io/google_containers/kube-apiserver-amd64 && \
docker tag gcr.io/google_containers/kube-controller-manager-amd64 gcr.io/google_containers/kube-controller-manager-amd64:v1.7.5 && \
docker rmi gcr.io/google_containers/kube-controller-manager-amd64 && \
docker tag gcr.io/google_containers/kube-proxy-amd64 gcr.io/google_containers/kube-proxy-amd64:v1.6.0 && \
docker rmi gcr.io/google_containers/kube-proxy-amd64 && \
docker tag gcr.io/google_containers/kube-scheduler-amd64 gcr.io/google_containers/kube-scheduler-amd64:v1.7.5 && \
docker rmi gcr.io/google_containers/kube-scheduler-amd64 && \
docker tag gcr.io/google_containers/pause-amd64 gcr.io/google_containers/pause-amd64:3.0 && \
docker rmi gcr.io/google_containers/pause-amd64
