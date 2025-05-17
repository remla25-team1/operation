# Kubernetes SSH & Join‑Command Fix

## Problem

When booting our Vagrant‑based Kubernetes cluster, the controller (`ctrl`) and worker nodes (`node‑1`, `node‑2`) come up fine, but the worker playbook (`node.yaml`) fails at the “generate join command” task:

```text
TASK [Generate kubeadm join command on controller] …
fatal: … Failed to connect to the host via ssh: … Permission denied (publickey,password).
```

Two root causes:

1. **SSH‑chaining**: `delegate_to: ctrl` makes Ansible SSH **from** the worker back **to** the controller—but the worker doesn’t yet have the controller’s private key.
2. **Per‑VM provisioning**: Vagrant runs each playbook with `--limit <this‑vm>`, so a controller‑only play is skipped entirely on workers, leaving no `join_cmd` in `hostvars`.

---

## Solution: Shared “join” Script in `/vagrant`

### 1. Controller playbook (`playbooks/ctrl.yaml`)

After `kubeadm init` and kubeconfig setup, I **add** these two tasks (under the same play):

```yaml
    - name: Generate kubeadm join command
      ansible.builtin.command: kubeadm token create --print-join-command
      register: join_cmd

    - name: Write join script into the shared folder
      ansible.builtin.copy:
        dest: /vagrant/join_cluster.sh
        mode: "0755"
        content: |
          #!/usr/bin/env bash
          {{ join_cmd.stdout }} --cri-socket /run/containerd/containerd.sock
```

- `/vagrant` is a synced folder on **all** VMs (and on the host).
- The controller writes `join_cluster.sh` exactly once.

### 2. Worker playbook (`playbooks/node.yaml`)

Replace any `delegate_to` or hostvars logic with a simple script invocation:

```yaml
- hosts: node-1:node-2
  become: true
  tasks:
    - name: Join this node to the Kubernetes cluster
      ansible.builtin.command: bash /vagrant/join_cluster.sh
      args:
        creates: /etc/kubernetes/kubelet.conf
```

- No SSH chaining.
- Vagrant runs this play per‑VM; each worker sees the same `/vagrant/join_cluster.sh`.

---

## Prepare & run the cluster

### 1. SSH Key Setup

1. Generate a **password‑less** keypair on your host (only once):

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   ```

2. **Copy** your public key into the project’s `ssh_keys/` folder:

   ```bash
   cp ~/.ssh/id_ed25519.pub ssh_keys/yourname.pub
   ```

### 3.2. Provisioning with Vagrant + Ansible

1. **Install Ansible** on your host:

   ```bash
   pip install --user ansible
   ```

2. **Boot & provision** all VMs:

   ```bash
   vagrant up
   ```

   Vagrant will, for each VM in turn:

   - SSH in with the default insecure key
   - Run `playbooks/general.yaml` → common OS setup
   - Run `playbooks/ctrl.yaml` on `ctrl`
   - Run `playbooks/node.yaml` on each worker

3. **Verify**:

   ```bash
   vagrant ssh ctrl
   kubectl get nodes
   ```
    You should see `ctrl`, `node-1`, and `node-2` all `Ready`. **Verify** your key is deployed into each VM’s `~/.ssh/authorized_keys`:

   ```bash
   vagrant ssh ctrl 
   cd .ssh
   cat authorized_keys
   ```

   You can now SSH into the cluster nodes from your host with ```ssh vagrant@192.168.56.100``` (for ```ctrl``` node).

---

## Explanation

- No cross‑node SSH*: Every Ansible session is from the host into each VM.
- Shared state: The join command is exported once to `/vagrant`, then consumed locally on each worker.

---

## Troubleshooting

- **“Permission denied (publickey)”**  
  Ensure your new public key is in `ssh_keys/*.pub` and the `authorized_key` Ansible task has run (check `~/.ssh/authorized_keys` inside each VM).

- **`/vagrant/join_cluster.sh` missing**  
  Rerun the controller play:
  ```bash
  vagrant provision ctrl --provision-with ansible
  ls -l /vagrant/join_cluster.sh
  ```

- **Re‑joining**  
  If a worker already joined, delete or move `/etc/kubernetes/kubelet.conf` inside the worker VM before reprovisioning.