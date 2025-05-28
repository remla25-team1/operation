#!/usr/bin/env bash
kubeadm join 192.168.56.100:6443 --token jihyhc.u4tsswbvq5gurjbx --discovery-token-ca-cert-hash sha256:6d4a5db06ff5b6b5d9a48fe9f3282a43b5fe16f9e24e3fb82efc45bb81dae2de  --cri-socket /run/containerd/containerd.sock
