```bash
vagrant ssh ctrl

ls -l /etc/kubernetes/admin.conf

sudo kubeadm token create --print-join-command --kubeconfig /etc/kubernetes/admin.conf # copy this output

kubectl get nodes
```

```bash
vagrant ssh node-1

sudo <copied-output> # something like sudo kubeadm join 192.168.57.100:6443 --token x7zxvv.bensccr0y4e6ghf6 --discovery-token-ca-cert-hash sha256:8ee476c1d992f8f2ad76f194061747c4e0057f9127d212ee6b61eb2fe840cf53 
```

Maybe we can turn this fix into Ansible playbook task? Problem is the delegate:ctrl will do ssh from terminal of host and that somehow is not working for me

```bash
cd .ssh
cat authorized_keys
```

I see my public key here. But doing this is not working:
```
ssh vagrant@192.168.56.100
Enter passphrase for key '/Users/annavisman/.ssh/id_ed25519': 
vagrant@192.168.56.100's password: 
Permission denied, please try again.
vagrant@192.168.56.100's password: 
Permission denied, please try again.
vagrant@192.168.56.100's password: 
vagrant@192.168.56.100: Permission denied (publickey,password).
```
I did not set a password for my public key, should I?


Fixed the public key ssh things.
Generated a new key pair
Copied public key to project in ssh_keys folder
Checked if they were transfered to each VM

Made changes to inventory, Vagrantfile, commented out connection:local from playbooks

Changed ansible_local to ansible. 

With ansible (regular):
The playbooks are run from your host machine.
Ansible connects to each VM over SSH and executes the tasks on the VMs (not on your host).
The only exception is if you use delegate_to: localhost or delegate_to: <some other host>, which runs that specific task elsewhere.
Ansible will run from your host machine.
It will connect to each VM over SSH using the inventory at shared/inventory.ini.
All playbooks and tasks will be executed on the VMs, not on your host.
Ansible cannot connect to each VM before the SSH keys are injected by your playbook.
Ansible needs to establish an SSH connection to the VM before it can run any playbook tasks—including those that set up or inject SSH keys.

How it works:

Vagrant automatically sets up the vagrant user with a default insecure private key (~/.vagrant.d/insecure_private_key) for initial SSH access.
Ansible uses this key (or another you specify in your inventory) to connect to the VMs.
Only after connecting can Ansible run tasks to add or change SSH keys.
