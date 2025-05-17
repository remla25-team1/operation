#!/usr/bin/env bash
kubeadm join 192.168.56.100:6443 --token 7mm1k6.y5zi2yea1555kgcd --discovery-token-ca-cert-hash sha256:909ba83cb0c2f2a887d9810906dba30405575662b82a38dc7f1ee7c74d23ec95  --cri-socket /run/containerd/containerd.sock
