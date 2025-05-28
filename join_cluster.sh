#!/usr/bin/env bash
kubeadm join 192.168.56.100:6443 --token dnoir6.fmacxg10byhjefhk --discovery-token-ca-cert-hash sha256:769cdb542ba07f8478974599b969c0c06115dd853b525f9dc0d8d874249704b7  --cri-socket /run/containerd/containerd.sock
