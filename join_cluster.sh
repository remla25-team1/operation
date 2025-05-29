#!/usr/bin/env bash
kubeadm join 192.168.56.100:6443 --token kvs1n3.c8uaaokhwh0jrnqa --discovery-token-ca-cert-hash sha256:78c5e5ead8647b8d1609b96b4a838716b1f869dadd10e2ae9fdfe68c9a42531e  --cri-socket /run/containerd/containerd.sock
