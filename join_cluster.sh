#!/usr/bin/env bash
kubeadm join 192.168.56.100:6443 --token a8u4p2.c9nidqiw2rv103nr --discovery-token-ca-cert-hash sha256:909ba83cb0c2f2a887d9810906dba30405575662b82a38dc7f1ee7c74d23ec95  --cri-socket /run/containerd/containerd.sock
